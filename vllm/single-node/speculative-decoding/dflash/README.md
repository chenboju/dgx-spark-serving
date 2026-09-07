**English** | [繁體中文](README.zh-TW.md)

# dflash/ — DFlash

Speculative decoding with a purpose-trained drafter from z-lab. The drafter is
trained against a specific target model, so acceptance is high enough to guess up
to 15 tokens at a time.

| Script | Target | Drafter | Tokens |
|---|---|---|---:|
| `gemma-4-26b-a4b-bf16-dflash.sh` | `google/gemma-4-26B-A4B-it` | `z-lab/gemma-4-26B-A4B-it-DFlash` | 15 |
| `gemma-4-26b-a4b-nvfp4-dflash.sh` | `nvidia/Gemma-4-26B-A4B-NVFP4` | same | 15 |
| `gpt-oss-120b-dflash.sh` | `openai/gpt-oss-120b` | `z-lab/gpt-oss-120b-DFlash` | 2 |

## Two attention backends

The two Gemma scripts deliberately give target and draft different backends:

```bash
--attention-backend triton_attn                                  # target model
--speculative-config '{..., "attention_backend": "flash_attn"}'   # drafter
```

The target runs Triton (better compatibility on ARM64), the drafter runs
FlashAttention (faster on short sequences).

## Gemma: building an image from an unmerged PR

DFlash support was still sitting in vLLM PR #41703 and had not reached a release.
Rather than rebuilding all of vLLM, both Gemma scripts use a **Python source
overlay** — copying only the PR's Python sources over an existing image's
site-packages:

```dockerfile
FROM vllm/vllm-openai:gemma4-0505-arm64-cu130
RUN SITE_PKG=$(python3 -c "import site; print(site.getsitepackages()[0])") \
    && git clone https://github.com/vllm-project/vllm.git /tmp/vllm-src \
    && cd /tmp/vllm-src \
    && git fetch origin pull/41703/head:dflash-pr \
    && git checkout dflash-pr \
    && cp -r /tmp/vllm-src/vllm/* "${SITE_PKG}/vllm/" \
    && rm -rf /tmp/vllm-src
```

Build time is **5–10 seconds**, rather than the hours it takes to compile vLLM
from scratch on ARM64. This is valid only because the PR touches the Python layer
and not the CUDA kernels — establishing that is what makes the approach sound.

The scripts build the `vllm-dflash-arm64-local` image automatically before
starting; no manual build step is needed.

## GPT-OSS: the tiktoken vocab trap

`gpt-oss-120b-dflash.sh` uses the official nightly image and needs no custom
build, but it does need a tokenizer workaround.

When openai-harmony loads its vocab it looks for the **original filename**
`o200k_base.tiktoken`, not tiktoken's usual SHA1-hashed name. This was confirmed
by tracing `openat()` system calls with `strace`.

So the file mounted into the container has to be prepared under the original name:

```bash
curl -L "https://openaipublic.blob.core.windows.net/encodings/o200k_base.tiktoken" \
  -o "$TIKTOKEN_CACHE_DIR/o200k_base.tiktoken"

docker run ... \
  -e TIKTOKEN_ENCODINGS_BASE="/tiktoken_encodings" \
  -v "$TIKTOKEN_CACHE_DIR:/tiktoken_encodings"
```

## Usage

```bash
source ../../../.env
./gemma-4-26b-a4b-nvfp4-dflash.sh    # builds the image first, automatically
```

The control group without speculative decoding is in
[../../gemma-4/](../../gemma-4/) and [../../gpt-oss/](../../gpt-oss/).
