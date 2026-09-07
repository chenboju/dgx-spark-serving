**English** | [繁體中文](README.zh-TW.md)

# multi-node/

Tensor-parallel serving across two DGX Sparks linked back-to-back over QSFP.
`mpirun` launches one rank per node with `tp_size=2`.

The hard part is not the launch command — it is that MPI has to reach *inside*
the containers. See [`../docs/multinode-networking.md`](../docs/multinode-networking.md)
for how the link itself was debugged.

## Order of operations

```bash
# On BOTH nodes
./01-init-container.sh          # persistent TRT-LLM container (sleep infinity)
./02-setup-mpi-ssh.sh           # sshd inside the container, port 2222

# On the HEAD node only
./check-mpi-ssh.sh <peer-ip>    # verify the peer is reachable before launching
./serve-nemotron3-120b.sh
```

The model must already be in `~/.cache/huggingface` on **both** nodes — downloading
from inside an MPI job races between ranks.

## Files

| File | Role |
|---|---|
| `config.env` | Shared settings: interface, container tag, ports, hostfile path |
| `_common.sh` | Hostfile publishing and the `tp_size=2` mpirun launch |
| `01-init-container.sh` | Starts the long-lived container — run on both nodes |
| `02-setup-mpi-ssh.sh` | sshd inside the container — run on both nodes |
| `check-mpi-ssh.sh` | Peer reachability check before launching |
| `serve-nemotron3-120b.sh` | Nemotron-3-Super-120B-A12B-NVFP4, port 8356 |
| `serve-llama4-scout.sh` | Llama-4-Scout-17B-16E-NVFP4, port 8355, seq len 8192 |
| `serve-gptoss-120b.sh` | GPT-OSS-120B, port 8887, seq len 32000 |
| `hostfile.example` | OpenMPI hostfile template |

## Three things to know before changing anything

**`NET_IFACE` in `config.env` is the single most important value.** Set it to
whatever `ibdev2netdev` reports as `Up`. MPI, NCCL and UCX are each pinned to it
explicitly; left to auto-select they will pick the management ethernet instead and
the job silently runs at 1 Gbit/s, or hangs, with no error either way.

**sshd runs on port 2222, not 22.** The container uses `--network host`, so the
host's own sshd already owns 22. The SSH configuration inside the container is
deliberately permissive — root login, no strict host key checking — which is safe
only because these two nodes sit on an isolated back-to-back segment with no
gateway. It is not reusable as-is on a shared network.

**Memory fraction is 0.4 here against 0.8 single-node.** Under unified memory, NCCL
buffers and the MPI runtime come out of the same pool as the KV cache. `--max_batch_size 1`
is likewise a memory ceiling, not a choice — it is the largest single constraint on
multi-node throughput.

Two of the three models set `NCCL_P2P_DISABLE` / `NCCL_IB_DISABLE`, forcing NCCL
onto TCP instead of RoCE. That made them start; it is a workaround, not a fix, and
the underlying issue is unresolved. Full reasoning with confidence levels:
[`../docs/tuning-notes.md`](../docs/tuning-notes.md).

## Known limitation

Link-local addresses are negotiated at boot and are not guaranteed stable across
reboots, while the hostfile pins them literally — so a reboot can silently break the
cluster. `hostfile` is in `.gitignore` because it contains real addresses;
`hostfile.example` is the template.
