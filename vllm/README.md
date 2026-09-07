**English** | [繁體中文](README.zh-TW.md)

# vLLM inference on DGX Spark

Deployment records for LLM inference on NVIDIA DGX Spark (GB10 Grace-Blackwell,
ARM64 / aarch64): single-node serving, two-node distributed inference,
quantisation formats, and speculative decoding configurations.

> **Status**: complete and no longer under active development. Configuration
> and debugging are the substance here; for measured numbers on this hardware see
> [What this does not cover](#what-this-does-not-cover).

## Why DGX Spark

GB10 is an ARM64 platform, and most prebuilt wheels and Docker images in the vLLM
ecosystem target x86_64. In practice the work goes into aarch64 wheel
dependencies, aligning CUDA / PyTorch / FlashInfer versions, and tuning memory
allocation under unified memory — none of which comes up on an ordinary x86 GPU
server.

## Contents

```
README.md  .env.example
docs/                 two-node build and debugging notes (2 documents)
cluster/              two-node Ray cluster: 8 scripts + vendor/
  vendor/               vLLM's own run_cluster.sh (third-party)
single-node/          single-node configurations, 26 scripts
  speculative-decoding/ 7 — the most technically dense group
    mtp/                  4 — Multi-Token Prediction
    dflash/               3 — DFlash
  gemma-4/              7 — BF16 / NVFP4 quantisation pairs
  gpt-oss/              4 — 120B MXFP4, including two parameterised launchers
  embedding/            3 — for GraphRAG / retrieval
  glm/                  2
  qwen/                 2
  domain/               1 — materials-science model
tools/                HF cache reporting, model download
upstream/             modifications to third-party projects (clearly marked as not mine)
```

Every directory carries its own `README.md` describing what is in it and why.

### Two-node distributed inference

Two DGX Sparks linked back-to-back over QSFP, running tensor parallelism (TP=2)
on a Ray cluster:

- [QSFP link debugging](docs/01-dual-node-networking.md) — from `ibdev2netdev`
  through Netplan link-local to SSH key exchange
- [vLLM across machines](docs/02-dual-node-vllm-deployment.md) — aligning network
  environment variables, Ray's memory monitor killing workers, syncing the cache
  to a worker with no outside network

**Verified working**:

| Model | Quantisation | Context | Notes |
|---|---|---|---|
| Qwen3-30B-A3B-Thinking-2507 | BF16 | 16K | MoE, TP=2 |
| GPT-OSS-120B | MXFP4 | 32K | 120B class, with fp8 KV cache |

**Not verified**: Nemotron-3-Super-120B (NVFP4 / FP8). NVFP4 would not start
reliably despite several attempts (`--enforce-eager`, `VLLM_USE_V1=0`); the FP8
weights were downloaded and synced to the worker but ran out of memory. Those
scripts are marked `[unverified]`.

### Speculative decoding

A small model guesses ahead, the large model verifies in one pass, cutting
per-token decode latency. Both methods are implemented; configurations live in
[single-node/speculative-decoding/](single-node/speculative-decoding/).

| | MTP | DFlash |
|---|---|---|
| Drafter | official assistant model | z-lab's purpose-trained drafter |
| `num_speculative_tokens` | 4 | 15 (Gemma) / 2 (GPT-OSS) |
| vLLM support | built into the preview image | **requires unmerged PR #41703** |
| Extra work | NVFP4 needs `gemma4_mtp.py` replaced | needs a self-built image |

Applicable combinations: Gemma-4-26B-A4B (BF16 / NVFP4, both methods),
Gemma-4-31B (BF16 / NVFP4, MTP), GPT-OSS-120B (DFlash).

### Single-node quantisation pairs

Baseline configurations without speculative decoding — which makes them the
control group for the section above:

| Model | BF16 | NVFP4 |
|---|:---:|:---:|
| Gemma-4-26B-A4B | ✓ | ✓ |
| Gemma-4-31B | ✓ | ✓ |
| Gemma-4-E4B | ✓ | — |
| DiffusionGemma-26B-A4B | ✓ | ✓ |

Also: GPT-OSS-120B (MXFP4), GLM-4.7-Flash, GLM-4-9B, QwQ-32B, Qwen3-Embedding,
and LLaMat-3, a materials-science domain model.

### Two pieces of engineering worth reading

**Building an image from an unmerged PR.** DFlash support was still sitting in
vLLM PR #41703 and had not reached a release.
[`speculative-decoding/dflash/`](single-node/speculative-decoding/dflash/) takes
a Python source overlay approach — copying only the PR's Python sources over an
existing image's site-packages, which builds in 5–10 seconds instead of the hours
it takes to compile vLLM from scratch on ARM64. This works only because the PR
touches the Python layer and not the CUDA kernels, which had to be established first.

**Tracing the tokenizer load path with strace.**
[`speculative-decoding/dflash/gpt-oss-120b-dflash.sh`](single-node/speculative-decoding/dflash/gpt-oss-120b-dflash.sh)
handles openai-harmony's vocab loading: tracing `openat()` calls with `strace`
showed it reads the original filename `o200k_base.tiktoken` rather than
tiktoken's usual SHA1-hashed name, so the mounted file has to be prepared under
the original name.

## Usage

```bash
cp .env.example .env
# fill in your HF_TOKEN and VLLM_API_KEY
source .env

./single-node/gpt-oss/gpt-oss-120b-mxfp4.sh
```

Every script checks the environment variables it needs before starting and aborts
with a message if any are missing.

## What this does not cover

This work is finished; the list below is scope, not a plan.

**Measured elsewhere.** Throughput, TTFT and SLO attainment for GPT-OSS-20B and
120B on this hardware were measured under vLLM and are published in the
companion project, **llm-serving-benchmark** (`dgx-spark-cuda/`). Headline results: DGX
Spark reaches about 0.28x an RTX 4090's closed-loop throughput on the same 37
cells, and under a 1000 ms TTFT / 50 ms ITL SLO a single Spark serves 120B at
concurrency 2 and 20B at concurrency 8.

**Never measured**, and therefore unquantified here:

- Single-node vs two-node scaling efficiency — the two-node configurations were
  brought up and verified, but never benchmarked against the single-node ones.
- Speedup and draft-token acceptance rate with speculative decoding on vs off.
  Both MTP and DFlash work; neither was measured, so the claim that DFlash's
  higher `num_speculative_tokens` pays off remains an inference from its design,
  not a result.
- Quality and speed trade-offs across quantisation formats (BF16 / NVFP4 /
  MXFP4 / FP8). The configurations exist as matched pairs specifically to make
  this comparison possible; the comparison was not run.

The scripts here are published as an engineering record of getting these models
to run on ARM64, not as a performance study.
