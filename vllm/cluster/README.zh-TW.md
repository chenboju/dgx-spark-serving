[English](README.md) | **繁體中文**

# cluster/ — 雙節點 Ray 叢集

兩台 DGX Spark 以 QSFP 直連，建立 Ray 叢集執行跨節點張量平行（TP=2）推論。

建置過程與踩過的坑見 [docs/](../docs/README.zh-TW.md)。

## 啟動順序

```bash
# 1. Spark A（head）
./start-head.sh

# 2. Spark B（worker）
./start-worker.sh

# 3. 回到 Spark A 確認兩節點都在
export VLLM_CONTAINER=$(docker ps --format '{{.Names}}' | grep -E 'node-')
docker exec $VLLM_CONTAINER ray status     # 應顯示 2 個 Active nodes

# 4. 起推論服務
./serve-qwen3-30b-a3b.sh

# 5. 驗活
./smoke-test.sh
```

## 檔案

| 檔案 | 說明 | 狀態 |
|---|---|---|
| `start-head.sh` | Spark A 起 Ray head，映射 8888 port | 已驗證 |
| `start-worker.sh` | Spark B 加入叢集 | 已驗證 |
| `serve-qwen3-30b-a3b.sh` | Qwen3-30B-A3B-Thinking-2507，BF16，16K | 已驗證 |
| `serve-gpt-oss-120b.sh` | GPT-OSS-120B，MXFP4 + fp8 KV cache，32K，port 8889 | 已驗證 |
| `serve-nemotron-3-super-120b-nvfp4.sh` | Nemotron-3-Super-120B NVFP4 + Marlin | 未驗證 |
| `serve-nemotron-3-super-120b-fp8.sh` | 同上 FP8 對照組 + FlashInfer MoE | 未驗證 |
| `smoke-test.sh` | curl `/v1/models` 驗活 | 已驗證 |
| `smoke-test.py` | Ray remote task，逐節點檢查 DNS / HTTPS 連通性 | 已驗證 |
| `vendor/` | vLLM 官方 `run_cluster.sh`，非本人撰寫 | — |

Qwen 用 8888、GPT-OSS 用 8889，兩個服務可並存。

## 兩個關鍵坑

**網卡環境變數必須在容器內那一層重設。** host 端 `-e` 傳進去不夠，`docker exec` 進去之後要再 export 一次：

```bash
export GLOO_SOCKET_IFNAME=enp1s0f1np1    # PyTorch distributed control plane
export NCCL_SOCKET_IFNAME=enp1s0f1np1    # NCCL collective，實際 tensor 傳輸
export TP_SOCKET_IFNAME=enp1s0f1np1      # vLLM tensor parallel socket 綁定
```

漏掉任何一個，vLLM 會安靜地退回慢速介面，或直接卡在初始化不動。

**`RAY_memory_monitor_refresh_ms=0` 不能省。** 模型載入時記憶體佔用會短暫衝高，Ray 的記憶體監控會誤判並直接砍掉 worker 進程。

## 120B 怎麼塞進兩台機器

`serve-gpt-oss-120b.sh` 的做法：

- MXFP4 原生量化權重，不讓它展開成 bf16
- `--kv-cache-dtype fp8`，KV cache 減半才撐得住 32K context
- `--gpu-memory-utilization 0.7`，DGX Spark 是 unified memory，留餘裕給系統

## 未驗證的部分

Nemotron-3-Super-120B 兩支腳本尚未成功啟動：

- NVFP4：多次嘗試（`--enforce-eager`、`VLLM_USE_V1=0`）仍不穩定
- FP8：權重下載並 rsync 至 worker 後，因記憶體不足放棄

保留這兩支是為了記錄嘗試過的 kernel backend 組合，作為後續除錯起點。
