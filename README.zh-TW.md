[English](README.md) | **繁體中文**

# DGX Spark 推論部署

在 NVIDIA DGX Spark（GB10、ARM64、統一記憶體）上建立 **vLLM 與 TensorRT-LLM 單機及雙節點推論服務**的部署腳本與除錯紀錄。兩台 Spark 以 QSFP 直連，分別透過 Ray 與 MPI-over-SSH 執行跨節點張量平行。

本專案的成果是可追溯的部署組態、成功啟動紀錄，以及 ARM64 相依、容器通訊與記憶體配置問題的處理方式。工作已完成，保留作為特定硬體環境的工程紀錄。

## 已完成的部署

| 範圍 | 成果 | 驗證邊界 |
|---|---|---|
| vLLM 雙節點 | Qwen3-30B-A3B BF16／16K；GPT-OSS-120B MXFP4 + fp8 KV／32K | 已驗證啟動；未量測跨節點效能 |
| TensorRT-LLM 雙節點 | Nemotron-3-Super-120B、Llama 4 Scout、GPT-OSS-120B | 已驗證啟動；未執行 benchmark |
| vLLM 單機 | 26 支腳本，涵蓋生成、embedding、量化對照與推測解碼 | 各模型條件見子目錄文件 |
| TensorRT-LLM 單機 | 5 個模型，共用啟動邏輯 | 各模型設定與限制見子目錄文件 |

vLLM 雙節點的 **Nemotron NVFP4／FP8 兩支腳本尚未驗證成功**，保留作為除錯紀錄。MTP／DFlash 與量化對照組態未進行速度提升、接受率或品質比較。

## 開始使用

先備妥 DGX Spark 的 NVIDIA driver、可使用 GPU 的 Docker 環境，以及所選模型與容器。腳本保留原環境的 image tag、網卡、IP、cache 與記憶體參數，執行前需依本機調整。

從本 repository 根目錄準備 vLLM 環境變數：

```bash
cp vllm/.env.example .env
# 編輯 .env，填入 HF_TOKEN 與 VLLM_API_KEY
source .env
```

若 GPT-OSS-120B 已完整快取於 `~/.cache/huggingface/`，可使用以下單機入口；這支腳本預設離線載入，不會自行下載缺少的權重：

```bash
bash vllm/single-node/gpt-oss/gpt-oss-120b-mxfp4.sh
```

| 目標 | 操作入口 |
|---|---|
| 選擇其他 vLLM 單機模型 | [單機腳本索引](vllm/single-node/README.zh-TW.md) |
| 建立兩台 Spark 的 Ray 叢集 | [雙節點啟動順序](vllm/cluster/README.zh-TW.md) |
| 使用 TensorRT-LLM | [環境與啟動流程](trtllm/README.zh-TW.md) |

## 工程重點

- **雙節點網路與容器通訊**：排查 QSFP 有 carrier 卻沒有可用 IPv4、分散式框架選錯介面，以及 MPI 必須透過容器內 sshd 啟動遠端 rank 的問題。見 [vLLM 網路紀錄](vllm/docs/01-dual-node-networking.zh-TW.md) 與 [TRT-LLM 網路紀錄](trtllm/docs/multinode-networking.zh-TW.md)。
- **統一記憶體配置**：模型權重、載入暫存、通訊 buffer 與 KV cache 共用記憶體池；記錄 Ray 記憶體監控與平行載入造成的失敗及對應設定。見 [vLLM 部署紀錄](vllm/docs/02-dual-node-vllm-deployment.zh-TW.md) 與 [TRT-LLM 調校筆記](trtllm/docs/tuning-notes.zh-TW.md)。
- **推測解碼整合**：保留 MTP／DFlash 的 image、來源覆蓋與 tokenizer 載入處理方式。見 [推測解碼索引](vllm/single-node/speculative-decoding/README.zh-TW.md)。

## 內容導覽

```text
.
├── README.md / README.zh-TW.md
├── vllm/
│   ├── cluster/       # Ray 雙節點、驗活與第三方 vendor 腳本
│   ├── single-node/   # 生成、embedding、量化與推測解碼
│   ├── docs/          # 網路與部署紀錄
│   ├── tools/         # Hugging Face 下載與 cache 報告
│   └── upstream/      # 對第三方專案的 patch 與 recipe
├── trtllm/
│   ├── single-node/   # 5 個模型與共用啟動邏輯
│   ├── multi-node/    # MPI-over-SSH、初始化與連線檢查
│   ├── tools/         # Backend 檢查與 Open WebUI
│   └── docs/          # 網路與記憶體調校
└── LICENSE
```

50 份 Markdown 提供 25 對中英文文件。框架完整索引：[vLLM](vllm/README.zh-TW.md)、[TensorRT-LLM](trtllm/README.zh-TW.md)。

## 效能資料與限制

專案 [**llm-serving-benchmark**](https://github.com/chenboju/llm-serving-benchmark) 保存 GPT-OSS-20B／120B 的單節點 vLLM 量測，以及 RTX 4090 與 DGX Spark 的比較。那些結果不代表本專案雙節點或 TensorRT-LLM 的效能。

本專案未量測單機與雙節點 scaling、vLLM 與 TensorRT-LLM 效能差異、推測解碼加速比或量化品質差異。已成功啟動的組態也不等於通用部署預設；部分 TRT-LLM 雙節點設定使用 TCP fallback 與隔離直連網段的 SSH 組態，細節見框架文件。

## 授權與來源

自有內容採 [MIT 授權](LICENSE)。[vendor/](vllm/cluster/vendor/README.zh-TW.md) 收錄未修改的 vLLM `run_cluster.sh`（Apache-2.0）；[upstream/](vllm/upstream/README.zh-TW.md) 保存對 eugr/spark-vllm-docker 的修改與來源說明。模型、容器與第三方程式適用各自授權。
