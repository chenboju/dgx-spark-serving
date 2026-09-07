[English](README.md) | **繁體中文**

# gpt-oss/ — GPT-OSS-120B 單機部署

120B 模型在單台 DGX Spark（128GB unified memory）上的服務組態。靠 MXFP4 原生量化才塞得下。

## 五支腳本的差異

| 腳本 | 行數 | 定位 |
|---|---:|---|
| `gpt-oss-120b-baseline.sh` | 29 | 最小可用組態，`--max-num-seqs 2` 保守起步 |
| `gpt-oss-120b-mxfp4.sh` | 43 | 日常使用版，參數已調過 |
| `gpt-oss-120b-dgx-spark-tuned.sh` | 224 | 參數化啟動器，用本機已下載的 cache 與自建 image |
| `gpt-oss-120b-standalone.sh` | 231 | 參數化啟動器，可自動下載模型與 fallback image |

DFlash 推測解碼版本在 [../speculative-decoding/dflash/](../speculative-decoding/dflash/README.zh-TW.md)。

前三支是直接的 `docker run`，讀起來一目了然。後兩支是 `set -euo pipefail` 的完整啟動器，
所有參數都可用環境變數覆蓋：

```bash
GPU_MEMORY_UTILIZATION=0.75 MAX_MODEL_LEN=32768 MAX_NUM_BATCHED_TOKENS=4096 \
  ./gpt-oss-120b-dgx-spark-tuned.sh
```

兩者的差別在模型來源：`dgx-spark-tuned` 假設 HF cache 裡已經有
`models--openai--gpt-oss-120b` 且使用自建的 `vllm-node` image；
`standalone` 則會在缺模型時自動下載，並在找不到本機 image 時 pull 備用。

## 雙節點版本

同一個模型的叢集版在 [cluster/serve-gpt-oss-120b.sh](../../cluster/serve-gpt-oss-120b.sh)，
TP=2 跨兩台機器，context 可以開到 32K。

單機 vs 雙節點本來會是這裡最乾淨的一組 scaling 量測——同模型、同量化，
能直接隔離出跨節點的實際效益。**但這個量測從未執行**，
因此雙節點那些繞道做法的代價是未量化的。
