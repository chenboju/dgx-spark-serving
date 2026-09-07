[English](02-dual-node-vllm-deployment.md) | **繁體中文**

# DGX Spark 雙節點 vLLM 跨機推論部署

在兩台 DGX Spark 上透過 QSFP 建立 Ray 分散式叢集，以 vLLM 執行 `Qwen3-30B-A3B-Thinking-2507` 跨節點張量平行（TP=2）推論。

前置作業見 [雙節點 QSFP 連線排查](01-dual-node-networking.zh-TW.md)。

## 環境

- **Head Node (Spark A)**：`gx10-bc71`，`169.254.203.69`
- **Worker Node (Spark B)**：`gx10-46f3`，`169.254.215.60`
- **高速網卡介面**：`enp1s0f1np1`
- **Docker 映像檔**：`nvcr.io/nvidia/vllm:26.02-py3`

## 關鍵：網路環境變數必須三個一起設

跨節點通訊會用到三套不同的傳輸層，各自讀不同的環境變數。只設其中一兩個，vLLM 會安靜地退回慢速介面（或直接卡死在初始化）：

| 變數 | 用途 |
|---|---|
| `NCCL_SOCKET_IFNAME` | NCCL collective（實際的 tensor 傳輸） |
| `GLOO_SOCKET_IFNAME` | PyTorch distributed 的 control plane |
| `TP_SOCKET_IFNAME` | vLLM tensor parallel 的 socket 綁定 |
| `UCX_NET_DEVICES` | UCX 傳輸層裝置選擇 |
| `OMPI_MCA_btl_tcp_if_include` | OpenMPI TCP BTL 介面白名單 |

另外 `RAY_memory_monitor_refresh_ms=0` 用來關閉 Ray 的記憶體監控——模型載入時記憶體佔用會短暫衝高，監控會誤判並直接砍掉 worker 進程。

## 啟動流程

### 步驟一：Head Node（Spark A）

見 [`cluster/start-head.sh`](../cluster/start-head.sh)：

```bash
export VLLM_IMAGE=nvcr.io/nvidia/vllm:26.02-py3
export VLLM_HOST_IP=169.254.203.69
export MN_IF_NAME=enp1s0f1np1

bash run_cluster.sh $VLLM_IMAGE $VLLM_HOST_IP --head ~/.cache/huggingface \
  -p 8888:8888 \
  -e VLLM_HOST_IP=$VLLM_HOST_IP \
  -e UCX_NET_DEVICES=$MN_IF_NAME \
  -e NCCL_SOCKET_IFNAME=$MN_IF_NAME \
  -e OMPI_MCA_btl_tcp_if_include=$MN_IF_NAME \
  -e GLOO_SOCKET_IFNAME=$MN_IF_NAME \
  -e TP_SOCKET_IFNAME=$MN_IF_NAME \
  -e RAY_memory_monitor_refresh_ms=0 \
  -e MASTER_ADDR=$VLLM_HOST_IP
```

### 步驟二：Worker Node（Spark B）

見 [`cluster/start-worker.sh`](../cluster/start-worker.sh)。變數與 head 對齊，差別在 `VLLM_HOST_IP` 指向自己、`MASTER_ADDR` 指向 head。

### 步驟三：確認叢集狀態

```bash
export VLLM_CONTAINER=$(docker ps --format '{{.Names}}' | grep -E 'node-')
docker exec $VLLM_CONTAINER ray status
# 預期顯示 2 個 Active nodes
```

### 步驟四：啟動推論伺服器

見 [`cluster/serve-qwen3-30b-a3b.sh`](../cluster/serve-qwen3-30b-a3b.sh)。注意 `--max-model-len` 要設上限，否則啟動時會 OOM。

### 步驟五：驗證

```bash
curl http://localhost:8888/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${VLLM_API_KEY}" \
  -d '{
    "model": "llm_chat",
    "messages": [{"role": "user", "content": "測試"}],
    "max_tokens": 100
  }'
```

## 疑難排解紀錄

### `No such container: pkill`

執行 `docker exec -it $VLLM_CONTAINER pkill -9 python` 失敗。

**原因**：當下沒有任何 `node-` 開頭的容器在跑，`$VLLM_CONTAINER` 是空字串，於是 `pkill` 被 docker 當成容器名稱解析。

**處理**：執行前先 `echo $VLLM_CONTAINER` 確認變數有抓到值。

### Worker 節點 `Failed to resolve 'huggingface.co'`

Spark B 拋出 DNS 解析失敗（`[Errno -3]`），無法下載模型權重。

**原因**：Worker 節點沒有對外網路。

**處理**：不動網路設定，直接走 QSFP 內網把 Spark A 已下載好的 HF cache 同步過去。

### 同步 cache 時 `Permission denied`

**原因**：Spark B 的 `~/.cache/huggingface` 是先前由 Docker 背景服務自動建立的，owner 變成 `root`，一般使用者無法寫入。

**處理**：

```bash
# 需要 -t 強制配置 TTY，sudo 才能在遠端讀到密碼輸入
ssh -t lab0616@169.254.215.60 "sudo chown -R lab0616:lab0616 ~/.cache/huggingface"

rsync -avP ~/.cache/huggingface/ lab0616@169.254.215.60:~/.cache/huggingface/
```

### `Errno 98 Address already in use`

前一次啟動的 Python 進程沒收乾淨。

```bash
docker exec -it $VLLM_CONTAINER pkill -9 python
```

叢集整個當掉時的完整清理：

```bash
docker stop $(docker ps -a -q --filter "name=node-") && \
docker rm $(docker ps -a -q --filter "name=node-")
```

## 常用維運指令

```bash
# 抓取當前 vLLM 容器名稱
export VLLM_CONTAINER=$(docker ps --format '{{.Names}}' | grep -E 'node-')

# 進入容器
docker exec -it $VLLM_CONTAINER /bin/bash

# 即時日誌（抓啟動期的錯誤）
docker logs -f $VLLM_CONTAINER

# GPU 使用率監控
watch -n 1 nvidia-smi

# 檢查 InfiniBand / RoCE 網卡對應
ibdev2netdev
```
