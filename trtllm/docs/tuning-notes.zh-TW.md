[English](tuning-notes.md) | **繁體中文**

# 調校筆記

本 repository 每一項非預設設定為什麼是現在這個值。每則標註信心水準：

- **[已驗證]**——該項改動經過隔離測試，確認能解決該症狀。
- **[經驗值]**——用二分法試出來的值；確切門檻因機器而異，機制是推論而非證明。
- **[假設]**——它有效，但改動是與其他項目一起做的，因果關係未經隔離。
  誠實標註，而不是包裝成「已經理解」。

底下幾乎所有項目背後的主要限制：DGX Spark 是 **unified memory**，
「GPU 記憶體」與「主機 RAM」是同一塊實體記憶體。任何讓主機 RAM 暴衝的東西
都會直接壓縮模型可用的空間，這使得好幾項設定的行為與獨立顯卡上不同。

---

## 記憶體

### `kv_cache_config.free_gpu_memory_fraction` **[經驗值]**

權重載入後，剩餘記憶體中交給 KV cache 的比例。實際使用的值：

| 模型 | 比例 | 備註 |
|---|---|---|
| Llama 3.1 8B（dense） | 0.9 | 權重小，餘裕多 |
| Llama 4 Scout 17B-16E | 0.9 | 單節點 |
| GLM-4.7 Flash | 0.9 | |
| Gemma 4 26B-A4B | 0.7 | 0.9 會配置失敗 |
| Nemotron 3 120B（單節點） | 0.8 | |
| Nemotron 3 120B（雙節點） | 0.4 | 見下方說明 |

多節點的值遠低於單節點，是因為每個 rank 現在還要放 NCCL 通訊緩衝區與 MPI runtime，
而在 unified memory 上這些跟 KV cache 出自同一塊記憶體。0.4 是第一個能穩定載入的值；
真正的上限沒有精確二分出來。

### `TRT_LLM_DISABLE_LOAD_WEIGHTS_IN_PARALLEL=1` **[已驗證]**

120B 模型必須設。TRT-LLM 的平行權重載入器會同時 staging 多個 shard，
造成主機 RAM 尖峰。在獨立顯卡的系統上這個尖峰由獨立的主機記憶體吸收；
在 unified memory 上它是在跟自己正在載入的權重搶空間，節點因而 OOM。
設定這一項會讓載入序列化——啟動變慢，但會成功。

### 大型載入前清除 page cache **[假設]**

```bash
sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'
```

在對付較大模型的配置失敗時用過。推論是：權重剛從磁碟串流進來，
page cache 正握著好幾 GB，而在 unified memory 上那份 cache 佔用的正是模型需要的空間。
核心理應在記憶體壓力下自行回收，所以這一步應該是多餘的——
但回收不是瞬間完成，配置在回收發生前就失敗了。

從未被隔離驗證為真正的解法，所以只記錄下來，沒有寫進啟動腳本。
真要依賴它之前值得重測。

### 多節點的 `--max_batch_size 1` **[經驗值]**

這不是效能選擇。扣掉權重、NCCL 緩衝區與 MPI 開銷之後，只塞得下這麼多。
它是目前壓著多節點吞吐的最大單一因素，也是最該優先重新處理的一項——
在它改善之前，tokens/s 的數字都會很難看。

---

## 模型架構專屬

### `kv_cache_config.enable_block_reuse: false` — Nemotron 3 **[已驗證]**

Nemotron 3 Super 是 Mamba-2 與 attention 的混合架構。Block reuse 的前提是
KV cache 具有純 attention 的語意——快取的 block 是產生它的那些 token 的純函數。
Mamba-2 層帶有遞迴的 SSM 狀態，不滿足這個前提，因此重用 block 並不成立。
NVIDIA 的 model card 要求關閉它；這關乎正確性，不是調校旋鈕。

### `moe_config.backend: CUTLASS` — Nemotron 3 **[已驗證]**

依 model card 指定，用於此架構的 MoE 層。

### `pip install --upgrade transformers` — GLM-4.7 Flash **[已驗證]**

`1.2.0rc6` 容器內附的 `transformers` 早於 GLM-4.7 的 config 格式，
載入時會因為無法辨識的架構而失敗。在容器內升級是權宜之計；
在衍生 image 裡釘住一個已知可用的版本才是正確做法。

### `disable_overlap_scheduler: true` — Llama 4 Scout、Nemotron 3 **[假設]**

在追這兩個模型的不穩定問題時加上的，穩定後就留著了。
它會關閉排程器與模型執行的重疊，以吞吐換取更可預測的記憶體行為。
沒有隔離驗證——現在可能已經不需要了。

---

## 多節點網路

### 把 MPI / NCCL / UCX 綁到 `enp1s0f1np1` **[已驗證]**

```
UCX_NET_DEVICES=enp1s0f1np1
NCCL_SOCKET_IFNAME=enp1s0f1np1
OMPI_MCA_btl_tcp_if_include=enp1s0f1np1
```

每台 Spark 同時有管理用的乙太網路 port 與 QSFP 連線。若讓這些函式庫自動選擇，
它們可能會挑到管理介面——job 還是會跑，只是走在慢上非常多的路徑上，
而且**不會有任何錯誤訊息**。三個都必須設定；它們是三個獨立的傳輸層，
各自做各自的介面選擇。

### `NCCL_P2P_DISABLE=1`、`NCCL_IB_DISABLE=1` — Llama 4、GPT-OSS **[假設]**

強迫 NCCL 走 TCP 而非 RDMA/P2P 路徑。在這兩個模型的 collective 初始化卡住時加上的。
**它讓模型能啟動，但這是繞道而非修復**——QSFP 上跑 TCP 明顯比 RoCE 慢，
等於白白放棄效能。Nemotron 3 不需要這一項就能跑，這暗示問題不純粹是 fabric 設定錯誤。
尚未解決。

這兩個變數會被傳遞**兩次**——一次透過 `docker exec -e`，一次透過 `mpirun -x`。
`-e` 涵蓋本地 rank；`-x` 則傳播到 mpirun 在對端啟動的 rank，
因為它不會繼承本地容器的環境。

### `--ulimit memlock=-1`、`--device /dev/infiniband` **[已驗證]**

RDMA 需要鎖定記憶體並直接存取 verbs 裝置。沒有無上限的 memlock，
傳輸層會退回較慢的路徑或直接失敗。

### 用 `sleep infinity` 容器 + `docker exec`，而非 `docker run` **[已驗證]**

多節點需要在模型載入**之前**，對端就有可連線的 sshd，
所以容器必須比任何單一指令活得久。單節點腳本的做法正好相反——
`docker run` 讓 server 當 PID 1——因為沒有對端要協調，會自行結束的容器比較單純。

---

## 從未量測

這個 backend 沒有任何吞吐數字。上面所有內容都是關於讓模型載入並維持運行；
沒有任何一項有 tokens/s、TTFT，或單節點對雙節點的 scaling 對比作為佐證。
專案已結束，這些數據不會再補——特別是 `max_batch_size 1` 與 `NCCL_*_DISABLE`
這兩項，是已知但永遠未量化的代價。
