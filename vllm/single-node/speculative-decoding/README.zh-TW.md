[English](README.md) | **繁體中文**

# speculative-decoding/ — 推測解碼

用小模型（drafter）先猜幾個 token，再讓大模型（target）一次驗證，藉此降低逐 token 解碼的延遲。
本目錄收錄兩種方法在 DGX Spark 上的實作組態。

| 目錄 | 方法 | 腳本數 |
|---|---|---:|
| [mtp/](mtp/README.zh-TW.md) | Multi-Token Prediction | 4 |
| [dflash/](dflash/README.zh-TW.md) | DFlash | 3 |

## 兩種方法的差異

| | MTP | DFlash |
|---|---|---|
| drafter 來源 | 官方 assistant 模型 | z-lab 訓練的專用 drafter |
| Gemma-4-26B 的 drafter | `google/gemma-4-26B-A4B-it-assistant` | `z-lab/gemma-4-26B-A4B-it-DFlash` |
| `num_speculative_tokens` | 4 | 15（Gemma）／2（GPT-OSS） |
| attention backend | 沿用預設 | target `triton_attn` + draft `flash_attn` |
| vLLM 支援狀態 | 預覽版 image 內建 | **需要未合併的 PR #41703** |
| 額外工程成本 | NVFP4 版需替換 `gemma4_mtp.py` | 需自建 image |

最值得注意的是 `num_speculative_tokens` 差了近四倍。DFlash 的 drafter 是專門訓練來配合
target 模型的，接受率高到可以一次猜 15 個 token；MTP 用的是通用 assistant 模型，
猜太多反而浪費驗證算力。

## 為什麼這部分獨立成一個目錄

投機解碼是本專案技術密度最高的部分：兩種方法、四種模型組態、各自要處理
上游程式碼尚未穩定的問題。放在 `gemma-4/` 底下會被當成一般組態變體，看不出來。

原本的模型家族分類仍保留在 [../gemma-4/](../gemma-4/README.zh-TW.md) 與 [../gpt-oss/](../gpt-oss/README.zh-TW.md)，
那兩處放的是**不含**推測解碼的基準組態——正好可以拿來當對照組。

## 對照關係

| 基準組態 | 對應的推測解碼版本 |
|---|---|
| `../gemma-4/gemma-4-26b-a4b-bf16.sh` | `mtp/gemma-4-26b-a4b-bf16-mtp.sh`、`dflash/gemma-4-26b-a4b-bf16-dflash.sh` |
| `../gemma-4/gemma-4-26b-a4b-nvfp4.sh` | `mtp/gemma-4-26b-a4b-nvfp4-mtp.sh`、`dflash/gemma-4-26b-a4b-nvfp4-dflash.sh` |
| `../gemma-4/gemma-4-31b-bf16.sh` | `mtp/gemma-4-31b-bf16-mtp.sh` |
| `../gemma-4/gemma-4-31b-nvfp4.sh` | `mtp/gemma-4-31b-nvfp4-mtp.sh` |
| `../gpt-oss/gpt-oss-120b-mxfp4.sh` | `dflash/gpt-oss-120b-dflash.sh` |

## 從未量測的部分

推測解碼的價值只能用數字證明，而這些數字始終沒有收集。本專案已結束，以下維持未解：

- 各組態開/關推測解碼的 throughput 對比。這裡每個組態在
  [../gemma-4/](../gemma-4/README.zh-TW.md) 與 [../gpt-oss/](../gpt-oss/README.zh-TW.md)
  都有成對的基準組態，當初就是為了做這個比較而配置的。
- draft token acceptance rate（vLLM 會在 log 輸出）。
- `num_speculative_tokens` 的甜蜜點——猜太多會讓驗證成本吃掉收益。

這會影響上面那張表該怎麼讀：「DFlash 敢一次猜 15 個而 MTP 只猜 4 個」的解釋，
**是從兩種 drafter 的訓練方式推論出來的，不是量測結果**。
這裡把它當作推論陳述，它從未在這套硬體上得到驗證。
