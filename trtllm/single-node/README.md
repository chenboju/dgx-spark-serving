**English** | [繁體中文](README.zh-TW.md)

# single-node/

One script per model, on a single DGX Spark. Each declares only what is different
about that model and sources [`_common.sh`](_common.sh) for the launch logic, so
the docker and `trtllm-serve` invocations exist in one place rather than five.

| Script | Model | Image | mem fraction | Notes |
|---|---|---|---:|---|
| `serve-llama3-8b.sh` | Llama-3.1-8B-Instruct-NVFP4 | 1.2.0rc6 | 0.9 | Dense 8B — used to validate the toolchain |
| `serve-llama4-scout.sh` | Llama-4-Scout-17B-16E-NVFP4 | 1.2.0rc6 | 0.9 | MoE; `disable_overlap_scheduler` |
| `serve-glm47-flash.sh` | GLM-4.7-Flash-NVFP4 | 1.2.0rc6 | 0.9 | Needs `transformers` upgraded in-container |
| `serve-gemma4-26b.sh` | Gemma-4-26B-A4B-NVFP4 | **1.3.0rc13** | 0.7 | MoE; needs a newer TRT-LLM release |
| `serve-nemotron3-120b.sh` | Nemotron-3-Super-120B-A12B-NVFP4 | 1.2.0rc6 | 0.8 | Hybrid Mamba-2 / MoE |

All models are NVFP4-quantised.

## Usage

```bash
export HF_TOKEN=hf_...
./serve-llama4-scout.sh          # optional [port] argument
../tools/check-backends.py 8355
```

## Why the values differ

`MEM_FRACTION` is `kv_cache_config.free_gpu_memory_fraction` — the share of
remaining memory given to the KV cache after weights are resident. Gemma 4 sits at
0.7 because 0.9 failed to allocate; Nemotron 3 at 0.8. These are empirical values,
not defaults, and DGX Spark's unified memory is why they matter more here than on a
discrete GPU.

Gemma 4 is the only model on a different container tag: `1.2.0rc6` does not support
it. GLM-4.7 runs on `1.2.0rc6` but its shipped `transformers` predates the model's
config format, so the script upgrades it inside the container — a workaround, not a
fix.

Every non-default setting, with its confidence level, is documented in
[`../docs/tuning-notes.md`](../docs/tuning-notes.md).

## Not benchmarked

These configurations were verified to load and stay up. No throughput or latency
numbers were collected for TensorRT-LLM — see
[Status and known gaps](../README.md#status-and-known-gaps).
