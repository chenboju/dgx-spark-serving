[English](README.md) | **繁體中文**

# single-node/

單台 DGX Spark，一個模型一支腳本。每支只宣告該模型的差異處，
再 source [`_common.sh`](_common.sh) 取得啟動邏輯，
讓 docker 與 `trtllm-serve` 的呼叫集中在一處，而不是散在五份檔案裡。

| 腳本 | 模型 | Image | 記憶體比例 | 備註 |
|---|---|---|---:|---|
| `serve-llama3-8b.sh` | Llama-3.1-8B-Instruct-NVFP4 | 1.2.0rc6 | 0.9 | Dense 8B——用來驗證工具鏈 |
| `serve-llama4-scout.sh` | Llama-4-Scout-17B-16E-NVFP4 | 1.2.0rc6 | 0.9 | MoE；設 `disable_overlap_scheduler` |
| `serve-glm47-flash.sh` | GLM-4.7-Flash-NVFP4 | 1.2.0rc6 | 0.9 | 需在容器內升級 `transformers` |
| `serve-gemma4-26b.sh` | Gemma-4-26B-A4B-NVFP4 | **1.3.0rc13** | 0.7 | MoE；需要較新的 TRT-LLM release |
| `serve-nemotron3-120b.sh` | Nemotron-3-Super-120B-A12B-NVFP4 | 1.2.0rc6 | 0.8 | Mamba-2 / MoE 混合架構 |

全部為 NVFP4 量化版本。

## 用法

```bash
export HF_TOKEN=hf_...
./serve-llama4-scout.sh          # 可選的 [port] 參數
../tools/check-backends.py 8355
```

## 為什麼數值各不相同

`MEM_FRACTION` 是 `kv_cache_config.free_gpu_memory_fraction`——權重載入後，
剩餘記憶體中交給 KV cache 的比例。Gemma 4 設 0.7 是因為 0.9 會配置失敗；
Nemotron 3 設 0.8。這些是實測值不是預設值，而 DGX Spark 的 unified memory
正是它們在這裡比在獨立顯卡上更關鍵的原因。

Gemma 4 是唯一用不同容器標籤的：`1.2.0rc6` 不支援它。
GLM-4.7 可以跑在 `1.2.0rc6`，但該版內附的 `transformers` 早於這個模型的 config 格式，
所以腳本會在容器內升級它——這是權宜之計，不是修復。

每一項非預設設定與其信心水準，見
[`../docs/tuning-notes.zh-TW.md`](../docs/tuning-notes.zh-TW.md)。

## 沒有 benchmark

這些組態驗證過可以載入並維持運行。TensorRT-LLM 側沒有收集任何吞吐或延遲數字，
見[現況與已知缺口](../README.zh-TW.md#現況與已知缺口)。
