[English](README.md) | **繁體中文**

# embedding/ — Embedding 服務

供 RAG / GraphRAG pipeline 使用的向量化服務，以 vLLM 的 `--runner pooling` 模式啟動。

| 腳本 | 模型 | Port | gpu-mem-util |
|---|---|---:|---:|
| `qwen3-embedding-0.6b.sh` | `Qwen/Qwen3-Embedding-0.6B` | 8001 | 0.05 |
| `qwen3-embedding-8b.sh` | `Qwen/Qwen3-Embedding-8B` | 8002 | 0.25 |
| `openscholar-retriever.sh` | `OpenSciLM/OpenScholar_Retriever` | 8001 | — |

0.6B 與 8B 用不同 port，可同時啟動做召回品質與延遲的對比。

## API

```bash
curl http://localhost:8001/v1/embeddings \
  -H "Content-Type: application/json" \
  -d '{"model": "Qwen3-Embedding-0.6B", "input": "測試文本"}'
```

`model` 欄位要填腳本裡的 `--served-model-name`，不是 HF 的完整 model id。

## 記憶體配置

`--gpu-memory-utilization` 依權重大小抓：0.6B 約 1.2GB（bf16），8B 約 16GB。
DGX Spark 是 128GB unified memory，所以 0.05 ≈ 6.4GB、0.25 ≈ 32GB。

> 8B 的 0.25 是按比例推估的起點，尚未實測。OOM 就往上調；要留記憶體給
> 同時運行的 LLM 服務就往下壓。

## 用途

`OpenScholar_Retriever` 是學術文獻檢索專用的 retriever，搭配
[domain/](../domain/README.zh-TW.md) 的材料科學模型使用。Qwen3-Embedding 系列則供
Microsoft GraphRAG 建索引。
