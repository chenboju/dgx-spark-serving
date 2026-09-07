**English** | [繁體中文](README.zh-TW.md)

# embedding/ — embedding services

Vectorisation services for RAG / GraphRAG pipelines, started in vLLM's
`--runner pooling` mode.

| Script | Model | Port | gpu-mem-util |
|---|---|---:|---:|
| `qwen3-embedding-0.6b.sh` | `Qwen/Qwen3-Embedding-0.6B` | 8001 | 0.05 |
| `qwen3-embedding-8b.sh` | `Qwen/Qwen3-Embedding-8B` | 8002 | 0.25 |
| `openscholar-retriever.sh` | `OpenSciLM/OpenScholar_Retriever` | 8001 | — |

The 0.6B and 8B services use different ports so they can run at the same time for
recall-quality and latency comparisons.

## API

```bash
curl http://localhost:8001/v1/embeddings \
  -H "Content-Type: application/json" \
  -d '{"model": "Qwen3-Embedding-0.6B", "input": "test text"}'
```

The `model` field takes the script's `--served-model-name`, not the full HF model id.

## Memory allocation

`--gpu-memory-utilization` follows the weight size: 0.6B is about 1.2 GB in bf16,
8B about 16 GB. DGX Spark has 128 GB of unified memory, so 0.05 ≈ 6.4 GB and
0.25 ≈ 32 GB.

> The 0.25 for 8B is a proportional estimate, not yet measured. Raise it on OOM;
> lower it to leave memory for an LLM service running alongside.

## What they are for

`OpenScholar_Retriever` is a retriever built for academic literature search, used
together with the materials-science model in [domain/](../domain/). The
Qwen3-Embedding models feed index building for Microsoft GraphRAG.
