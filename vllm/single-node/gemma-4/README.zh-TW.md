[English](README.md) | **繁體中文**

# gemma-4/ — 量化對照組

Gemma 4 系列在 DGX Spark 上的基準組態。**不含推測解碼**——那部分獨立在
[../speculative-decoding/](../speculative-decoding/README.zh-TW.md)，這裡的腳本正好是它的對照組。

## 矩陣

| 模型 | BF16 | NVFP4 | 類型 |
|---|:---:|:---:|---|
| Gemma-4-26B-A4B | ✓ | ✓ | MoE，啟用參數 4B |
| Gemma-4-31B | ✓ | ✓ | dense |
| Gemma-4-E4B | ✓ | — | 輕量版 |
| DiffusionGemma-26B-A4B | ✓ | ✓ | diffusion 架構 |

檔名對應規則：`gemma-4-<size>-<quant>.sh`

## 量化取捨

`BF16` 原始權重 vs `NVFP4`（`nvidia/Gemma-4-*-NVFP4`）。NVFP4 省下的記憶體換成更長的
context——同樣 `--gpu-memory-utilization 0.6`，NVFP4 版能開到 96K 而 BF16 版開不到。

## 加上推測解碼

以下組態在 [../speculative-decoding/](../speculative-decoding/README.zh-TW.md) 有對應版本：

| 本目錄的基準 | 推測解碼版本 |
|---|---|
| `gemma-4-26b-a4b-bf16.sh` | MTP、DFlash 各一支 |
| `gemma-4-26b-a4b-nvfp4.sh` | MTP、DFlash 各一支 |
| `gemma-4-31b-bf16.sh` | MTP |
| `gemma-4-31b-nvfp4.sh` | MTP |

要做開/關推測解碼的效能對比，就是拿這兩邊同名的腳本互跑。

## 純文字模式

Gemma 4 是多模態模型，但這些組態只跑文字。用 `--limit-mm-per-prompt '{"image":0,"audio":0}'`
關掉視覺與音訊，省下來的記憶體換更長的 context（`--max-model-len 96000`）。

## 從未量測的部分

各組態的 throughput 與推測解碼的 acceptance rate 從未量測，
所以上面那張 BF16 / NVFP4 矩陣記錄的是**哪些組態跑得起來**，不是它們的優劣比較。
成對的配置本來就是為了做這個比較，但比較沒有執行。
完整範圍界定見 vLLM README 的[未涵蓋的範圍](../../README.zh-TW.md#未涵蓋的範圍)。
