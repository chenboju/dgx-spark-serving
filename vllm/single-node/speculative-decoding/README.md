**English** | [繁體中文](README.zh-TW.md)

# speculative-decoding/

A small model (the drafter) guesses a few tokens ahead, and the large model (the
target) verifies them in one pass, cutting per-token decode latency. This
directory holds configurations for two methods on DGX Spark.

| Directory | Method | Scripts |
|---|---|---:|
| [mtp/](mtp/) | Multi-Token Prediction | 4 |
| [dflash/](dflash/) | DFlash | 3 |

## How the two differ

| | MTP | DFlash |
|---|---|---|
| Drafter source | official assistant model | purpose-trained drafter from z-lab |
| Drafter for Gemma-4-26B | `google/gemma-4-26B-A4B-it-assistant` | `z-lab/gemma-4-26B-A4B-it-DFlash` |
| `num_speculative_tokens` | 4 | 15 (Gemma) / 2 (GPT-OSS) |
| Attention backend | default | target `triton_attn` + draft `flash_attn` |
| vLLM support | built into the preview image | **requires unmerged PR #41703** |
| Extra work | NVFP4 needs `gemma4_mtp.py` replaced | needs a self-built image |

The most striking difference is the near-fourfold gap in
`num_speculative_tokens`. DFlash's drafter is trained specifically to match its
target, so acceptance is high enough to guess 15 tokens at a time; MTP uses a
general assistant model, where guessing too far just wastes verification compute.

## Why this is its own directory

Speculative decoding is the most technically dense part of this project: two
methods, four model configurations, each dealing with upstream code that has not
stabilised. Filed under `gemma-4/` it would read as an ordinary configuration
variant and the substance would be invisible.

The model-family grouping still exists in [../gemma-4/](../gemma-4/) and
[../gpt-oss/](../gpt-oss/), holding the configurations **without** speculative
decoding — which makes them the control group.

## Matching pairs

| Baseline configuration | Speculative-decoding counterpart |
|---|---|
| `../gemma-4/gemma-4-26b-a4b-bf16.sh` | `mtp/gemma-4-26b-a4b-bf16-mtp.sh`, `dflash/gemma-4-26b-a4b-bf16-dflash.sh` |
| `../gemma-4/gemma-4-26b-a4b-nvfp4.sh` | `mtp/gemma-4-26b-a4b-nvfp4-mtp.sh`, `dflash/gemma-4-26b-a4b-nvfp4-dflash.sh` |
| `../gemma-4/gemma-4-31b-bf16.sh` | `mtp/gemma-4-31b-bf16-mtp.sh` |
| `../gemma-4/gemma-4-31b-nvfp4.sh` | `mtp/gemma-4-31b-nvfp4-mtp.sh` |
| `../gpt-oss/gpt-oss-120b-mxfp4.sh` | `dflash/gpt-oss-120b-dflash.sh` |

## What was never measured

The value of speculative decoding can only be shown with numbers, and those
numbers were never collected. This work is finished, so the following stay open:

- Throughput with speculative decoding on vs off, per configuration. Every
  configuration here has a matched baseline in [../gemma-4/](../gemma-4/) and
  [../gpt-oss/](../gpt-oss/) precisely so this comparison could be run.
- Draft token acceptance rate, which vLLM logs.
- The sweet spot for `num_speculative_tokens` — guess too far and verification
  cost eats the gain.

This matters for how the table above should be read: the explanation of why
DFlash can afford to guess 15 tokens where MTP guesses 4 is **an inference from
how the two drafters are trained, not a measured result**. It is stated here as
reasoning, and it was never verified on this hardware.
