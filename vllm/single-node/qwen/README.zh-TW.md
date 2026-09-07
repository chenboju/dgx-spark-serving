[English](README.md) | **繁體中文**

# qwen/ — Qwen 系列

| 腳本 | 模型 | 說明 |
|---|---|---|
| `qwen3-30b-a3b-thinking.sh` | `Qwen/Qwen3-30B-A3B-Thinking-2507` | MoE，啟用參數 3B，推理型 |
| `qwq-32b.sh` | `Qwen/QwQ-32B` | dense 32B，推理型 |

## 與雙節點版的關係

`qwen3-30b-a3b-thinking.sh` 的叢集版本在
[cluster/serve-qwen3-30b-a3b.sh](../../cluster/serve-qwen3-30b-a3b.sh)，
是本專案**第一個成功跑通的雙節點組態**。

單機版與雙節點版的差異：

| | 單機 | 雙節點 |
|---|---|---|
| TP size | 1 | 2 |
| 網卡環境變數 | 不需要 | NCCL / GLOO / TP 三組必設 |
| 啟動方式 | `docker run` | `docker exec` 進 Ray 容器 |

## 備註

Thinking 系列會輸出 reasoning 內容，客戶端要能處理 `reasoning_content` 欄位，
或在請求時關掉。
