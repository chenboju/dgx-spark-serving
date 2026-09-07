**English** | [繁體中文](tuning-notes.zh-TW.md)

# Tuning notes

Why each non-default setting in this repo is there. Entries are marked:

- **[verified]** — the change was isolated and observed to fix the symptom.
- **[empirical]** — the value was found by bisecting until it worked; the exact
  threshold is machine-specific and the mechanism is inferred, not proven.
- **[hypothesis]** — it worked, but the change was made alongside others and
  the causal link has not been isolated. Flagged honestly rather than dressed
  up as understanding.

The dominant constraint behind almost everything below: a DGX Spark has
**unified memory**, so "GPU memory" and "host RAM" are the same physical pool.
Anything that spikes host RAM directly reduces what the model can use, which
makes several settings behave differently than they would on a discrete GPU.

---

## Memory

### `kv_cache_config.free_gpu_memory_fraction` **[empirical]**

Fraction of remaining memory handed to the KV cache after weights are resident.
Values used:

| Model | Fraction | Note |
|---|---|---|
| Llama 3.1 8B (dense) | 0.9 | small weights, lots of headroom |
| Llama 4 Scout 17B-16E | 0.9 | single node |
| GLM-4.7 Flash | 0.9 | |
| Gemma 4 26B-A4B | 0.7 | 0.9 failed to allocate |
| Nemotron 3 120B (single node) | 0.8 | |
| Nemotron 3 120B (two nodes) | 0.4 | see below |

The multi-node value is far lower than the single-node one because each rank now
also holds NCCL communication buffers and the MPI runtime, and on unified memory
those come out of the same pool as the KV cache. 0.4 was the first value that
loaded reliably; the true ceiling was not bisected precisely.

### `TRT_LLM_DISABLE_LOAD_WEIGHTS_IN_PARALLEL=1` **[verified]**

Required for the 120B models. TRT-LLM's parallel weight loader stages shards
concurrently, which spikes host RAM. On a discrete-GPU system that spike is
absorbed by separate host memory; on unified memory it is competing with the
weights it is loading, and the node OOMs. Setting this serialises the load —
slower startup, but it completes.

### Dropping page cache before a large load **[hypothesis]**

```bash
sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'
```

Used while fighting allocation failures on the larger models. The reasoning:
weights were just streamed off disk, so the page cache is holding gigabytes of
them, and on unified memory that cache is occupying the same pool the model
needs. The kernel should reclaim it under pressure, so this should be
unnecessary — but reclaim is not instant, and allocation failed before it
happened.

Never isolated as the fix, so it is recorded rather than wired into the launch
scripts. Worth retesting before relying on it.

### `--max_batch_size 1` on multi-node **[empirical]**

Not a performance choice. After weights, NCCL buffers, and MPI overhead, this
was what fit. It is the single biggest thing holding back multi-node throughput
and the first thing to revisit — the tokens/s number will be poor until it moves.

---

## Model-architecture-specific

### `kv_cache_config.enable_block_reuse: false` — Nemotron 3 **[verified]**

Nemotron 3 Super is a hybrid Mamba-2 / attention model. Block reuse assumes a
KV cache with pure attention semantics, where a cached block is a pure function
of the tokens that produced it. Mamba-2 layers carry recurrent SSM state, which
does not satisfy that assumption, so reusing blocks is not sound. NVIDIA's model
card requires disabling it; doing so is correctness-critical, not a tuning knob.

### `moe_config.backend: CUTLASS` — Nemotron 3 **[verified]**

Per the model card, for the MoE layers on this architecture.

### `pip install --upgrade transformers` — GLM-4.7 Flash **[verified]**

The `1.2.0rc6` container ships a `transformers` predating GLM-4.7's config
format, so the load fails on an unrecognised architecture. Upgrading in-container
is a workaround; pinning a known-good version in a derived image would be the
right fix.

### `disable_overlap_scheduler: true` — Llama 4 Scout, Nemotron 3 **[hypothesis]**

Added while chasing instability on these two models and kept once things were
stable. It disables overlapping the scheduler with model execution, trading
throughput for more predictable memory behaviour. Not isolated — it may be
unnecessary now.

---

## Multi-node networking

### Pinning MPI / NCCL / UCX to `enp1s0f1np1` **[verified]**

```
UCX_NET_DEVICES=enp1s0f1np1
NCCL_SOCKET_IFNAME=enp1s0f1np1
OMPI_MCA_btl_tcp_if_include=enp1s0f1np1
```

Each Spark has both a management ethernet port and the QSFP link. Left to
auto-select, these libraries can pick the management interface — the job still
runs, just over a vastly slower path, with no error to indicate it. All three
must be set; they are three independent transport layers and each does its own
interface selection.

### `NCCL_P2P_DISABLE=1`, `NCCL_IB_DISABLE=1` — Llama 4, GPT-OSS **[hypothesis]**

Forces NCCL onto TCP instead of the RDMA/P2P paths. Added when these two models
hung during collective init. It made them start, but it is a workaround, not a
fix — TCP over the QSFP link is measurably slower than RoCE, so this is leaving
performance on the table. Nemotron 3 runs without it, which suggests the problem
is not purely a fabric misconfiguration. Unresolved.

These are passed **twice** — once via `docker exec -e` and again via `mpirun -x`.
The `-e` covers the local rank; `-x` propagates to the rank mpirun spawns on the
peer, which does not inherit the local container's environment.

### `--ulimit memlock=-1`, `--device /dev/infiniband` **[verified]**

RDMA requires pinning memory and direct access to the verbs device. Without
unlimited memlock the transport falls back or fails outright.

### `sleep infinity` container + `docker exec`, not `docker run` **[verified]**

Multi-node needs a reachable sshd on the peer *before* the model loads, so the
container has to outlive any single command. The single-node scripts do the
opposite — `docker run` with the server as PID 1 — because there is no peer to
coordinate with and a self-terminating container is simpler.

---

## Never measured

No throughput numbers exist for this backend. Everything above is about getting
models to load and stay up; none of it is backed by tokens/s, TTFT, or a
single-node vs two-node scaling comparison. This work is finished and those
numbers will not be added — the `max_batch_size 1` and `NCCL_*_DISABLE` items in
particular are permanently unquantified costs.
