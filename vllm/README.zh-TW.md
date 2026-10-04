[English](README.md) | **繁體中文**

# DGX Spark 上的 vLLM 推論部署

在 NVIDIA DGX Spark（GB10 Grace-Blackwell，ARM64 / aarch64）上部署大型語言模型推論服務的實作紀錄，涵蓋單機服務、雙節點分散式推論、量化格式與推測解碼（speculative decoding）的組態實驗。

> **狀態**：已完成，不再持續開發。本專案的內容是組態與除錯；
> 這套硬體的實測數字見[未涵蓋的範圍](#未涵蓋的範圍)。

## 為什麼是 DGX Spark

GB10 是 ARM64 平台，多數 vLLM 生態的預建 wheel 與 Docker image 都以 x86_64 為主。實務上大量時間花在：aarch64 的 wheel 相依、CUDA / PyTorch / FlashInfer 版本對齊、以及 unified memory 架構下的記憶體配置調校——這些在一般 x86 GPU 伺服器上不會遇到。

## 內容

```
README.md  .env.example  .gitignore
docs/                 雙節點建置與除錯紀錄（2 篇）
cluster/              雙節點 Ray 叢集：8 支腳本 + vendor/
  vendor/               vLLM 官方 run_cluster.sh（第三方）
single-node/          單機組態，共 26 支腳本
  speculative-decoding/ 7 支——推測解碼，技術密度最高的一組
    mtp/                  4 支——Multi-Token Prediction
    dflash/               3 支——DFlash
  gemma-4/              7 支——BF16 / NVFP4 量化對照
  gpt-oss/              4 支——120B MXFP4，含兩種參數化啟動器
  embedding/            3 支——GraphRAG / 檢索用
  glm/                  2 支
  qwen/                 2 支
  domain/               1 支——材料科學領域模型
tools/                HF cache 空間分析、模型下載
upstream/             對第三方專案的修改（明確標示非本人作品）
```

每個目錄都有自己的 `README.md` 說明該層內容與取捨。

### 雙節點分散式推論

兩台 DGX Spark 以 QSFP 直連，建立 Ray 叢集執行跨節點張量平行（TP=2）：

- [QSFP 連線排查](docs/01-dual-node-networking.zh-TW.md)——從 `ibdev2netdev` 到 Netplan link-local 到 SSH 金鑰交換
- [vLLM 跨機部署](docs/02-dual-node-vllm-deployment.zh-TW.md)——網路環境變數對齊、Ray 記憶體監控誤殺、無外網 worker 的 cache 同步

**已驗證可用**：

| 模型 | 量化 | Context | 備註 |
|---|---|---|---|
| Qwen3-30B-A3B-Thinking-2507 | BF16 | 16K | MoE，TP=2 |
| GPT-OSS-120B | MXFP4 | 32K | 120B 級，搭配 fp8 KV cache |

**尚未驗證**：Nemotron-3-Super-120B（NVFP4 / FP8）。NVFP4 經多次嘗試（`--enforce-eager`、
`VLLM_USE_V1=0`）仍未穩定啟動；FP8 版權重下載並同步至 worker 後，因記憶體不足放棄。
相關腳本標註為 `[未驗證]`。

### 推測解碼

用小模型先猜、大模型一次驗證，降低逐 token 解碼延遲。兩種方法都實作了，
組態收在 [single-node/speculative-decoding/](single-node/speculative-decoding/README.zh-TW.md)。

| | MTP | DFlash |
|---|---|---|
| drafter | 官方 assistant 模型 | z-lab 專用 drafter |
| `num_speculative_tokens` | 4 | 15（Gemma）／2（GPT-OSS） |
| vLLM 支援狀態 | 預覽版 image 內建 | **需要未合併的 PR #41703** |
| 額外工程 | NVFP4 版需替換 `gemma4_mtp.py` | 需自建 image |

適用組合：Gemma-4-26B-A4B（BF16 / NVFP4，兩種方法都有）、Gemma-4-31B（BF16 / NVFP4，MTP）、
GPT-OSS-120B（DFlash）。

### 單機量化對照

不含推測解碼的基準組態，正好可當上面的對照組：

| 模型 | BF16 | NVFP4 |
|---|:---:|:---:|
| Gemma-4-26B-A4B | ✓ | ✓ |
| Gemma-4-31B | ✓ | ✓ |
| Gemma-4-E4B | ✓ | — |
| DiffusionGemma-26B-A4B | ✓ | ✓ |

其他：GPT-OSS-120B（MXFP4）、GLM-4.7-Flash、GLM-4-9B、QwQ-32B、Qwen3-Embedding、以及材料科學領域模型 LLaMat-3。

### 值得一提的兩處工程

**從未合併的 PR 建 image。** DFlash 支援當時停在 vLLM PR #41703，沒進 release。
[`speculative-decoding/dflash/`](single-node/speculative-decoding/dflash/README.zh-TW.md) 的做法是
Python source overlay——只把 PR 的 Python 原始碼疊到現成 image 的 site-packages 上，
建置 5~10 秒，而不是在 ARM64 上從頭編譯 vLLM 的數小時。前提是判斷出該 PR 只動 Python 層、
沒改 CUDA kernel。

**strace 追出 tokenizer 的載入路徑。**
[`speculative-decoding/dflash/gpt-oss-120b-dflash.sh`](single-node/speculative-decoding/dflash/gpt-oss-120b-dflash.sh)
處理了 openai-harmony 的 vocab 載入問題——用 `strace` 追 `openat()` 系統呼叫，
確認它讀的是原始檔名 `o200k_base.tiktoken`，而非 tiktoken 慣用的 SHA1 雜湊檔名，
因此掛載路徑必須照原始檔名準備。

## 使用方式

```bash
cp .env.example .env
# 編輯 .env 填入你的 HF_TOKEN 與 VLLM_API_KEY
source .env

./single-node/gpt-oss/gpt-oss-120b-mxfp4.sh
```

所有腳本都會在啟動前檢查必要的環境變數，未設定時直接中止並提示。

## 未涵蓋的範圍

本專案已結束，以下是範圍界定，不是待辦清單。

**已在別處量測。** GPT-OSS-20B 與 120B 在這套硬體上的 throughput、TTFT 與 SLO
達成率，已在姊妹專案 [**llm-serving-benchmark**](https://github.com/chenboju/llm-serving-benchmark)（[`dgx-spark-cuda/`](https://github.com/chenboju/llm-serving-benchmark/tree/main/dgx-spark-cuda)）以 vLLM 完成量測。
主要結果：同一組 37 個 cell 下，DGX Spark 的 closed-loop 吞吐約為 RTX 4090 的
0.28 倍；在 TTFT 1000 ms / ITL 50 ms 的 SLO 下，單台 Spark 跑 120B 的併發上限是
2、跑 20B 是 8。

**從未量測**，因此以下代價在本專案內是未知數：

- 單節點 vs 雙節點的 scaling 效率——雙節點組態已驗證可用，但沒有與單節點對跑過。
- 推測解碼開/關的加速比與 draft token acceptance rate。MTP 與 DFlash 兩種方法都能跑，
  但都沒量過；因此「DFlash 敢一次猜 15 個 token 是划算的」目前仍是從設計推論，
  不是實測結論。
- 量化格式（BF16 / NVFP4 / MXFP4 / FP8）的品質與速度取捨。這些組態刻意做成成對的
  對照組就是為了做這個比較，但比較沒有執行。

這裡的腳本是以「在 ARM64 上把這些模型跑起來」的工程紀錄形式發布，不是效能研究。
