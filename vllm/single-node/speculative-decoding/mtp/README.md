**English** | [繁體中文](README.zh-TW.md)

# mtp/ — Multi-Token Prediction

Uses Gemma 4's official assistant models as the drafter, speculating 4 tokens at a
time.

| Script | Target | Drafter |
|---|---|---|
| `gemma-4-26b-a4b-bf16-mtp.sh` | `google/gemma-4-26B-A4B-it` | `google/gemma-4-26B-A4B-it-assistant` |
| `gemma-4-26b-a4b-nvfp4-mtp.sh` | `nvidia/Gemma-4-26B-A4B-NVFP4` | same |
| `gemma-4-31b-bf16-mtp.sh` | `google/gemma-4-31B-it` | `google/gemma-4-31B-it-assistant` |
| `gemma-4-31b-nvfp4-mtp.sh` | `nvidia/Gemma-4-31B-IT-NVFP4` | same |

Configuration:

```bash
--speculative-config '{"method": "mtp", "model": "<drafter>", "num_speculative_tokens": 4}'
```

All four use `vllm/vllm-openai:gemma4-0505-arm64-cu130` — the ARM64 preview image,
which has MTP support built in.

## NVFP4 needs gemma4_mtp.py replaced

Running MTP on the quantised models hits a bug in the image's `gemma4_mtp.py`.
Both NVFP4 scripts fetch a fixed version and mount it into the container:

```bash
wget -qO /tmp/gemma4_mtp.py \
  https://raw.githubusercontent.com/vllm-project/vllm/d8b3826648da6b407f8c55/vllm/model_executor/models/gemma4_mtp.py

docker run ... \
  -v /tmp/gemma4_mtp.py:/usr/local/lib/python3.12/dist-packages/vllm/model_executor/models/gemma4_mtp.py
```

**The commit hash is pinned deliberately.** Upstream is still changing this file,
and pinning is what makes the behaviour reproducible; point at a branch instead
and an upstream change will silently produce different results one day.

The BF16 scripts do not need this patch.

## Usage

```bash
source ../../../.env
./gemma-4-26b-a4b-nvfp4-mtp.sh
```

The control group without speculative decoding is in [../../gemma-4/](../../gemma-4/).
