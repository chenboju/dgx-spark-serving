**English** | [繁體中文](README.zh-TW.md)

# TensorRT-LLM serving on DGX Spark

Scripts and engineering notes for running NVFP4-quantised LLMs with
TensorRT-LLM on NVIDIA DGX Spark — both on a single unit, and tensor-parallel
across two units linked back-to-back over QSFP.

Models brought up: **Llama 3.1 8B**, **Llama 4 Scout 17B-16E**, **GLM-4.7
Flash**, **Gemma 4 26B-A4B**, **Nemotron 3 Super 120B-A12B**, **GPT-OSS 120B**.

The interesting part is not the launch commands — it is the two-node work.
Getting a 120B model to load across two Sparks meant fixing the QSFP link,
building an MPI-over-SSH channel that reaches *inside* containers, and working
around unified memory, where "GPU memory" and "host RAM" are the same pool and
several standard TRT-LLM assumptions stop holding.

## Layout

One script per model. Each declares only what is different about that model —
container tag, memory fraction, architecture-specific flags — and sources a
`_common.sh` holding the launch logic, so the docker and mpirun invocations
exist in one place rather than five.

```
single-node/
  _common.sh                  docker invocation + config generation
  serve-llama3-8b.sh          dense 8B — used to validate the toolchain
  serve-llama4-scout.sh       MoE 17B-16E
  serve-glm47-flash.sh        MoE, needs a transformers upgrade in-container
  serve-gemma4-26b.sh         MoE 26B-A4B, needs a newer TRT-LLM release
  serve-nemotron3-120b.sh     hybrid Mamba-2 / MoE, single node
multi-node/
  config.env                  shared settings (interface, container, ports)
  _common.sh                  hostfile publish + tp_size=2 mpirun launch
  01-init-container.sh        persistent TRT-LLM container   — run on both nodes
  02-setup-mpi-ssh.sh         sshd inside the container      — run on both nodes
  check-mpi-ssh.sh            verify peer reachability before launching
  serve-nemotron3-120b.sh     tensor-parallel servers        — head node only
  serve-llama4-scout.sh
  serve-gptoss-120b.sh
  hostfile.example            OpenMPI hostfile template
tools/
  check-backends.py           distinguish "still loading" from "crashed"
  start-openwebui.sh          chat frontend against the OpenAI-compatible API
docs/
  multinode-networking.md     how the two-node link was debugged
  tuning-notes.md             why every non-default setting is what it is
```

Each directory has its own README: [single-node/](single-node/README.md), [multi-node/](multi-node/README.md), [tools/](tools/README.md).

## Usage

Single node:

```bash
export HF_TOKEN=hf_...
./single-node/serve-llama4-scout.sh          # optional [port] argument
./tools/check-backends.py 8355
```

Two nodes — set `NET_IFACE` in `multi-node/config.env` to whatever
`ibdev2netdev` reports as `Up`, put a hostfile at `~/openmpi-hostfile`, then:

```bash
# on BOTH nodes
./multi-node/01-init-container.sh
./multi-node/02-setup-mpi-ssh.sh

# on the head node
./multi-node/check-mpi-ssh.sh <peer-ip>
./multi-node/serve-nemotron3-120b.sh
```

The model must be in `~/.cache/huggingface` on **both** nodes first —
downloading from inside an MPI job races between ranks.

## Three problems worth reading about

**The link was up but had no address.** One node held carrier on the QSFP port
with no IPv4 at all, so the nodes were never on the same L3 segment. `ip link`
showed "up" on both and hid it. Full writeup:
[docs/multinode-networking.md](docs/multinode-networking.md).

**MPI has to reach inside the container.** `mpirun` launches remote ranks over
SSH, but the ranks live in containers, so the container needs its own sshd — on
a non-standard port, since `--network host` means the host's sshd already owns
22. See [`02-setup-mpi-ssh.sh`](multi-node/02-setup-mpi-ssh.sh), including its
security caveats.

**Unified memory changes the rules.** Parallel weight loading OOMs the node,
because the host-RAM spike competes with the weights being loaded. MPI and NCCL
buffers come out of the same budget as the KV cache, which is why the multi-node
memory fraction is 0.4 against 0.8 on a single node. All of it, with confidence
levels, in [docs/tuning-notes.md](docs/tuning-notes.md).

## Status and known gaps

Honest accounting of what this is not:

- **No benchmarks for TensorRT-LLM.** Everything here is about getting models to
  load and stay up. There are no tokens/s, TTFT, or single-vs-two-node scaling
  numbers for this backend, so the cost of the workarounds below is unquantified.
  GPT-OSS-20B and 120B on this same hardware *were* measured, but **under vLLM,
  not TensorRT-LLM** — see the companion project [**llm-serving-benchmark**](https://github.com/chenboju/llm-serving-benchmark)
  ([`dgx-spark-cuda/`](https://github.com/chenboju/llm-serving-benchmark/tree/main/dgx-spark-cuda)). Those numbers say nothing about the configurations here;
  the two backends were never compared.
- **`--max_batch_size 1` on multi-node** is a memory ceiling, not a choice.
  Multi-node throughput is bad until this moves.
- **`NCCL_P2P_DISABLE` / `NCCL_IB_DISABLE`** on two of the models force NCCL
  onto TCP instead of RoCE. It made them start; it is not a fix, and the
  underlying issue is unresolved.
- **Link-local addressing is not reboot-stable.** The hostfile pins addresses
  that can change, which will silently break the cluster.
- **Container SSH config is permissive by design** (root login, no strict host
  key checking). Safe only because the two nodes sit on an isolated
  back-to-back segment with no gateway. Not reusable as-is on a shared network.

These scripts target one specific hardware setup and are published as an
engineering record, not as a general-purpose tool.
