[English](README.md) | **繁體中文**

# DGX Spark 上的 TensorRT-LLM 服務

在 NVIDIA DGX Spark 上以 TensorRT-LLM 跑 NVFP4 量化 LLM 的腳本與工程筆記——
涵蓋單機，以及兩台機器以 QSFP 直連後的跨節點張量平行。

已跑起來的模型：**Llama 3.1 8B**、**Llama 4 Scout 17B-16E**、**GLM-4.7 Flash**、
**Gemma 4 26B-A4B**、**Nemotron 3 Super 120B-A12B**、**GPT-OSS 120B**。

有意思的不是啟動指令，而是雙節點的部分。要讓 120B 模型跨兩台 Spark 載入，
必須修好 QSFP 連線、建立一條能進到**容器內部**的 MPI-over-SSH 通道，
並繞過 unified memory 的限制——在那裡「GPU 記憶體」與主機 RAM 是同一個池，
好幾個 TRT-LLM 的標準假設因此不再成立。

## 目錄結構

一個模型一支腳本。每支只宣告該模型的差異處——容器標籤、記憶體比例、
架構專屬旗標——再 source 共用的 `_common.sh` 取得啟動邏輯，
讓 docker 與 mpirun 的呼叫集中在一處，而不是散在五份檔案裡。

```
single-node/
  _common.sh                  docker 呼叫與組態產生
  serve-llama3-8b.sh          dense 8B——用來驗證工具鏈
  serve-llama4-scout.sh       MoE 17B-16E
  serve-glm47-flash.sh        MoE，需在容器內升級 transformers
  serve-gemma4-26b.sh         MoE 26B-A4B，需要較新的 TRT-LLM release
  serve-nemotron3-120b.sh     混合 Mamba-2 / MoE，單機
multi-node/
  config.env                  共用設定（網卡、容器、port）
  _common.sh                  hostfile 發布與 tp_size=2 的 mpirun 啟動
  01-init-container.sh        常駐 TRT-LLM 容器      — 兩個節點都要跑
  02-setup-mpi-ssh.sh         容器內的 sshd          — 兩個節點都要跑
  check-mpi-ssh.sh            啟動前驗證 peer 可達性
  serve-nemotron3-120b.sh     張量平行服務          — 只在 head 節點跑
  serve-llama4-scout.sh
  serve-gptoss-120b.sh
  hostfile.example            OpenMPI hostfile 範本
tools/
  check-backends.py           區分「仍在載入」與「已崩潰」
  start-openwebui.sh          對接 OpenAI 相容 API 的聊天前端
docs/
  multinode-networking.md     雙節點連線是怎麼除錯出來的
  tuning-notes.md             每個非預設參數為什麼是現在這個值
```

每個子目錄都有自己的 README：[single-node/](single-node/README.zh-TW.md)、[multi-node/](multi-node/README.zh-TW.md)、[tools/](tools/README.zh-TW.md)。

## 用法

單機：

```bash
export HF_TOKEN=hf_...
./single-node/serve-llama4-scout.sh          # 可選的 [port] 參數
./tools/check-backends.py 8355
```

雙節點——把 `multi-node/config.env` 的 `NET_IFACE` 設成 `ibdev2netdev`
回報為 `Up` 的那張網卡，在 `~/openmpi-hostfile` 放好 hostfile，然後：

```bash
# 兩個節點都要跑
./multi-node/01-init-container.sh
./multi-node/02-setup-mpi-ssh.sh

# 只在 head 節點跑
./multi-node/check-mpi-ssh.sh <peer-ip>
./multi-node/serve-nemotron3-120b.sh
```

模型必須**事先**存在於兩個節點的 `~/.cache/huggingface`——
在 MPI job 內部下載會讓各 rank 互相競爭。

## 三個值得一讀的問題

**連線是 up 的，但沒有位址。** 其中一個節點的 QSFP port 有 carrier，
卻完全沒有 IPv4，因此兩節點從來不在同一個 L3 網段。`ip link` 兩邊都顯示 "up"，
把問題藏了起來。完整說明：[docs/multinode-networking.md](docs/multinode-networking.zh-TW.md)。

**MPI 必須能進到容器裡。** `mpirun` 透過 SSH 啟動遠端 rank，但 rank 跑在容器內，
所以容器需要自己的 sshd——而且要用非標準 port，因為 `--network host` 之下
host 的 sshd 已經佔用 22。見 [`02-setup-mpi-ssh.sh`](multi-node/02-setup-mpi-ssh.sh)，
含其中的安全性但書。

**Unified memory 改變了規則。** 平行載入權重會讓節點 OOM，因為主機 RAM 的尖峰
與正在載入的權重互相競爭。MPI 與 NCCL 的緩衝區跟 KV cache 出自同一個預算，
這就是多節點的記憶體比例是 0.4、而單機是 0.8 的原因。
完整說明與信心水準見 [docs/tuning-notes.md](docs/tuning-notes.zh-TW.md)。

## 現況與已知缺口

誠實交代這份東西**不是**什麼：

- **TensorRT-LLM 沒有 benchmark。** 這裡的內容全都是關於讓模型載入並維持運行。
  這個 backend 沒有 tokens/s、TTFT，也沒有單機對雙節點的 scaling 數字，
  所以下面那些繞道做法的代價是未量化的。
  GPT-OSS-20B 與 120B 在**同一套硬體**上確實有實測，但那是**用 vLLM 跑的，
  不是 TensorRT-LLM**——見姊妹專案 **llm-serving-benchmark**（`dgx-spark-cuda/`）。
  那些數字不能用來說明這裡的組態；兩個 backend 從未互相比較過。
- **多節點的 `--max_batch_size 1`** 是記憶體天花板，不是選擇。
  在這一項改善之前，多節點的吞吐都很差。
- **`NCCL_P2P_DISABLE` / `NCCL_IB_DISABLE`** 用在其中兩個模型上，
  強迫 NCCL 走 TCP 而非 RoCE。它讓模型能啟動；這不是修復，
  底層問題仍未解決。
- **Link-local 位址在重開機後不穩定。** hostfile 釘住的位址可能改變，
  屆時叢集會無聲地壞掉。
- **容器 SSH 設定刻意寬鬆**（允許 root 登入、不做嚴格 host key 檢查）。
  只因為兩個節點位於隔離的直連網段、沒有對外閘道才算安全。
  在共用網路上不可原樣沿用。

這些腳本針對一套特定硬體，發布目的是作為工程紀錄，而非通用工具。
