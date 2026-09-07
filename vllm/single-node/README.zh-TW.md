[English](README.md) | **繁體中文**

# single-node/ — 單機服務組態

單台 DGX Spark（GB10，128GB unified memory，ARM64）上的 vLLM 服務腳本，依模型家族分類。

| 目錄 | 腳本數 | 內容 |
|---|---:|---|
| [speculative-decoding/](speculative-decoding/README.zh-TW.md) | 7 | **MTP 與 DFlash 兩種推測解碼**，技術密度最高的一組 |
| [gemma-4/](gemma-4/README.zh-TW.md) | 7 | Gemma 4 系列，BF16 / NVFP4 量化對照 |
| [gpt-oss/](gpt-oss/README.zh-TW.md) | 4 | GPT-OSS-120B，MXFP4，含兩種參數化啟動器 |
| [embedding/](embedding/README.zh-TW.md) | 3 | Embedding 服務，供 GraphRAG / 檢索使用 |
| [glm/](glm/README.zh-TW.md) | 2 | GLM-4.7-Flash、GLM-4-9B |
| [qwen/](qwen/README.zh-TW.md) | 2 | Qwen3-30B-A3B-Thinking、QwQ-32B |
| [domain/](domain/README.zh-TW.md) | 1 | 材料科學領域模型 |

`gemma-4/` 與 `gpt-oss/` 放的是**不含推測解碼**的基準組態，正好是
`speculative-decoding/` 的對照組——要量測推測解碼的效益就是拿兩邊互跑。

## 共通約定

所有腳本都：

- 用 Docker 啟動，掛載 `~/.cache/huggingface` 共用模型快取
- 啟動前檢查必要環境變數，未設定直接中止（`: "${HF_TOKEN:?...}"`）
- 預設服務在 `localhost:8000`，embedding 用 8001 / 8002 錯開

```bash
cp ../.env.example ../.env   # 填入 HF_TOKEN 與 VLLM_API_KEY
source ../.env
./gpt-oss/gpt-oss-120b-mxfp4.sh
```

## DGX Spark 上的記憶體特性

GB10 是 **unified memory 架構**，CPU 與 GPU 共用 128GB。這代表 `--gpu-memory-utilization`
的意義跟一般獨立顯卡不同——設太高會把系統本身也擠掉。實務上：

| 模型規模 | 建議起點 |
|---|---|
| < 1B（embedding） | 0.05 |
| 8B 級 | 0.25 |
| 26–32B | 0.6 – 0.7 |
| 120B（量化後） | 0.7 – 0.9 |

這些是實測起點不是定值，換 context 長度或 batch 大小都要重調。
