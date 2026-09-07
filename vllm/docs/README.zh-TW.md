[English](README.md) | **繁體中文**

# docs/ — 建置與除錯紀錄

兩台 DGX Spark 從開箱直連到跑起跨節點推論的完整過程。按順序讀。

| 文件 | 內容 |
|---|---|
| [01-dual-node-networking.md](01-dual-node-networking.zh-TW.md) | QSFP 實體連線排查：`ibdev2netdev` → Netplan link-local → SSH 金鑰交換 |
| [02-dual-node-vllm-deployment.md](02-dual-node-vllm-deployment.zh-TW.md) | vLLM 跨機部署：網路變數對齊、Ray 記憶體誤殺、無外網 worker 的 cache 同步 |

## 這兩篇在記什麼

不是操作手冊，是**故障排除紀錄**——每個步驟都對應一個實際卡住的問題：

- 網卡狀態 `UP` 卻沒有 IPv4 位址，因為 Netplan 的 link-local 設定沒套用
- 五個網路環境變數（NCCL / GLOO / TP / UCX / OpenMPI）各管一段傳輸層，只設一兩個會安靜地退回慢速介面
- Ray 記憶體監控在模型載入時誤判，把 worker 進程砍掉
- Worker 節點沒有對外網路，改走 QSFP 內網 rsync 同步 HF cache
- 同步時 `Permission denied`，因為目標資料夾是 Docker 背景服務以 root 建立的

對應的可執行腳本在 [cluster/](../cluster/README.zh-TW.md)。
