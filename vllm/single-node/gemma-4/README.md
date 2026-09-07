**English** | [繁體中文](README.zh-TW.md)

# gemma-4/ — quantisation pairs

Baseline configurations for the Gemma 4 family on DGX Spark. **No speculative
decoding** — that lives in [../speculative-decoding/](../speculative-decoding/),
which makes the scripts here its control group.

## Matrix

| Model | BF16 | NVFP4 | Type |
|---|:---:|:---:|---|
| Gemma-4-26B-A4B | ✓ | ✓ | MoE, 4B active parameters |
| Gemma-4-31B | ✓ | ✓ | dense |
| Gemma-4-E4B | ✓ | — | lightweight |
| DiffusionGemma-26B-A4B | ✓ | ✓ | diffusion architecture |

Filenames follow `gemma-4-<size>-<quant>.sh`.

## The quantisation trade-off

`BF16` original weights versus `NVFP4` (`nvidia/Gemma-4-*-NVFP4`). The memory
NVFP4 saves buys context length — at the same
`--gpu-memory-utilization 0.6`, the NVFP4 build reaches 96K where BF16 does not.

## Adding speculative decoding

These configurations have counterparts in
[../speculative-decoding/](../speculative-decoding/):

| Baseline here | Speculative-decoding version |
|---|---|
| `gemma-4-26b-a4b-bf16.sh` | one MTP, one DFlash |
| `gemma-4-26b-a4b-nvfp4.sh` | one MTP, one DFlash |
| `gemma-4-31b-bf16.sh` | MTP |
| `gemma-4-31b-nvfp4.sh` | MTP |

Comparing speculative decoding on and off means running the same-named scripts
from both sides against each other.

## Text-only mode

Gemma 4 is multimodal, but these configurations run text only.
`--limit-mm-per-prompt '{"image":0,"audio":0}'` turns off vision and audio, and
the memory that frees buys context length (`--max-model-len 96000`).

## What was never measured

Throughput per configuration and speculative-decoding acceptance rates were never
measured, so the BF16 / NVFP4 matrix above records **which configurations run**,
not how they compare. The pairs exist to make that comparison possible; it was
not carried out. See
[What this does not cover](../../README.md#what-this-does-not-cover) in the
vLLM README for the full scope.
