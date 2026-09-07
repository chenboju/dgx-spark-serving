**English** | [繁體中文](README.zh-TW.md)

# gpt-oss/ — GPT-OSS-120B, single node

Serving configurations for a 120B model on one DGX Spark (128 GB unified memory).
MXFP4 native quantisation is what makes it fit.

## How the scripts differ

| Script | Lines | Role |
|---|---:|---|
| `gpt-oss-120b-baseline.sh` | 29 | Minimal working configuration, conservative `--max-num-seqs 2` |
| `gpt-oss-120b-mxfp4.sh` | 43 | Everyday version, parameters already tuned |
| `gpt-oss-120b-dgx-spark-tuned.sh` | 224 | Parameterised launcher, uses the local cache and a self-built image |
| `gpt-oss-120b-standalone.sh` | 231 | Parameterised launcher, can download the model and fall back to a pulled image |

The DFlash speculative-decoding version is in
[../speculative-decoding/dflash/](../speculative-decoding/dflash/).

The first three are plain `docker run` invocations and read at a glance. The last
two are full `set -euo pipefail` launchers where every parameter can be overridden
by an environment variable:

```bash
GPU_MEMORY_UTILIZATION=0.75 MAX_MODEL_LEN=32768 MAX_NUM_BATCHED_TOKENS=4096 \
  ./gpt-oss-120b-dgx-spark-tuned.sh
```

They differ in where the model comes from: `dgx-spark-tuned` assumes
`models--openai--gpt-oss-120b` is already in the HF cache and uses a self-built
`vllm-node` image, while `standalone` downloads the model if it is missing and
pulls a fallback image if the local one is not found.

## Two-node version

The cluster version of the same model is at
[cluster/serve-gpt-oss-120b.sh](../../cluster/serve-gpt-oss-120b.sh) — TP=2 across
two machines, with context up to 32K.

Single-node against two-node would have been the cleanest scaling measurement
available here — same model, same quantisation, so it isolates the real benefit of
going cross-node. **It was never run**, so the cost of the two-node workarounds is
unquantified.
