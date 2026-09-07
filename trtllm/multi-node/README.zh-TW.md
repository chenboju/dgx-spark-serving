[English](README.md) | **繁體中文**

# multi-node/

兩台 DGX Spark 以 QSFP 直連，執行跨節點張量平行服務。
`mpirun` 在每個節點各啟動一個 rank，`tp_size=2`。

困難的不是啟動指令，而是 MPI 必須能連進**容器內部**。
連線本身怎麼除錯出來的，見
[`../docs/multinode-networking.zh-TW.md`](../docs/multinode-networking.zh-TW.md)。

## 執行順序

```bash
# 兩個節點都要跑
./01-init-container.sh          # 常駐 TRT-LLM 容器（sleep infinity）
./02-setup-mpi-ssh.sh           # 容器內的 sshd，port 2222

# 只在 head 節點跑
./check-mpi-ssh.sh <peer-ip>    # 啟動前先驗證對端可達
./serve-nemotron3-120b.sh
```

模型必須**事先**存在於兩個節點的 `~/.cache/huggingface`——
在 MPI job 內部下載會讓各 rank 互相競爭。

## 檔案

| 檔案 | 作用 |
|---|---|
| `config.env` | 共用設定：網卡、容器標籤、port、hostfile 路徑 |
| `_common.sh` | hostfile 發布與 `tp_size=2` 的 mpirun 啟動 |
| `01-init-container.sh` | 啟動常駐容器——兩個節點都要跑 |
| `02-setup-mpi-ssh.sh` | 容器內的 sshd——兩個節點都要跑 |
| `check-mpi-ssh.sh` | 啟動前的對端可達性檢查 |
| `serve-nemotron3-120b.sh` | Nemotron-3-Super-120B-A12B-NVFP4，port 8356 |
| `serve-llama4-scout.sh` | Llama-4-Scout-17B-16E-NVFP4，port 8355，seq len 8192 |
| `serve-gptoss-120b.sh` | GPT-OSS-120B，port 8887，seq len 32000 |
| `hostfile.example` | OpenMPI hostfile 範本 |

## 動手改之前要知道的三件事

**`config.env` 裡的 `NET_IFACE` 是最關鍵的一個值。** 設成 `ibdev2netdev`
回報為 `Up` 的那張網卡。MPI、NCCL、UCX 三者各自被明確綁到它；
若讓它們自動選擇，會挑到管理用的乙太網路，然後 job 安靜地以 1 Gbit/s 執行，
或者直接卡住——兩種情況都**不會有錯誤訊息**。

**sshd 跑在 port 2222，不是 22。** 容器使用 `--network host`，
所以 host 自己的 sshd 已經佔用 22。容器內的 SSH 設定刻意寬鬆——
允許 root 登入、不做嚴格 host key 檢查——只因為這兩個節點位於隔離的直連網段、
沒有對外閘道才算安全。在共用網路上不可原樣沿用。

**這裡的記憶體比例是 0.4，單節點是 0.8。** 在 unified memory 下，
NCCL 緩衝區與 MPI runtime 跟 KV cache 出自同一塊記憶體。
`--max_batch_size 1` 同樣是記憶體天花板而非選擇——它是壓著多節點吞吐的最大單一因素。

三個模型裡有兩個設了 `NCCL_P2P_DISABLE` / `NCCL_IB_DISABLE`，
強迫 NCCL 走 TCP 而非 RoCE。這讓它們能啟動；這是繞道不是修復，底層問題仍未解決。
完整理由與信心水準見
[`../docs/tuning-notes.zh-TW.md`](../docs/tuning-notes.zh-TW.md)。

## 已知限制

Link-local 位址是開機時協商的，跨重開機不保證穩定，
而 hostfile 是逐字釘住這些位址的——所以重開機可能讓叢集無聲地壞掉。
`hostfile` 已列入 `.gitignore`，因為它含實際位址；`hostfile.example` 是範本。
