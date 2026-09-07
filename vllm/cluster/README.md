**English** | [繁體中文](README.zh-TW.md)

# cluster/ — two-node Ray cluster

Two DGX Sparks linked back-to-back over QSFP, running a Ray cluster for
cross-node tensor-parallel (TP=2) inference.

How it was built and what went wrong along the way: [docs/](../docs/).

## Startup order

```bash
# 1. Spark A (head)
./start-head.sh

# 2. Spark B (worker)
./start-worker.sh

# 3. Back on Spark A, confirm both nodes joined
export VLLM_CONTAINER=$(docker ps --format '{{.Names}}' | grep -E 'node-')
docker exec $VLLM_CONTAINER ray status     # should show 2 Active nodes

# 4. Start the inference service
./serve-qwen3-30b-a3b.sh

# 5. Check it is alive
./smoke-test.sh
```

## Files

| File | Description | Status |
|---|---|---|
| `start-head.sh` | Ray head on Spark A, maps port 8888 | verified |
| `start-worker.sh` | Spark B joins the cluster | verified |
| `serve-qwen3-30b-a3b.sh` | Qwen3-30B-A3B-Thinking-2507, BF16, 16K | verified |
| `serve-gpt-oss-120b.sh` | GPT-OSS-120B, MXFP4 + fp8 KV cache, 32K, port 8889 | verified |
| `serve-nemotron-3-super-120b-nvfp4.sh` | Nemotron-3-Super-120B NVFP4 + Marlin | unverified |
| `serve-nemotron-3-super-120b-fp8.sh` | same, FP8 control + FlashInfer MoE | unverified |
| `smoke-test.sh` | curl `/v1/models` liveness check | verified |
| `smoke-test.py` | Ray remote task, per-node DNS / HTTPS reachability | verified |
| `vendor/` | vLLM's own `run_cluster.sh`, not written by me | — |

Qwen uses 8888 and GPT-OSS 8889, so both services can run side by side.

## Two things that will catch you out

**The interface environment variables have to be set again inside the container.**
Passing them with `-e` from the host is not enough; after `docker exec` you must
export them once more:

```bash
export GLOO_SOCKET_IFNAME=enp1s0f1np1    # PyTorch distributed control plane
export NCCL_SOCKET_IFNAME=enp1s0f1np1    # NCCL collectives, the actual tensor traffic
export TP_SOCKET_IFNAME=enp1s0f1np1      # vLLM tensor-parallel socket binding
```

Miss any one of them and vLLM silently falls back to a slow interface, or hangs
during initialisation.

**`RAY_memory_monitor_refresh_ms=0` is not optional.** Memory use spikes briefly
while the model loads, and Ray's memory monitor misreads that spike and kills the
worker process.

## Fitting 120B across two machines

What `serve-gpt-oss-120b.sh` does:

- keeps the MXFP4 native quantised weights rather than letting them expand to bf16
- `--kv-cache-dtype fp8` — halving the KV cache is what makes 32K context fit
- `--gpu-memory-utilization 0.7` — DGX Spark is unified memory, so leave the
  system some headroom

## Not verified

Neither Nemotron-3-Super-120B script has started successfully:

- **NVFP4**: still unstable after several attempts (`--enforce-eager`, `VLLM_USE_V1=0`)
- **FP8**: weights downloaded and rsynced to the worker, then abandoned on out-of-memory

They are kept as a record of the kernel-backend combinations already tried, as a
starting point for further debugging.
