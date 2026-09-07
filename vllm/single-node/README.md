**English** | [繁體中文](README.zh-TW.md)

# single-node/ — single-machine serving configurations

vLLM serving scripts for one DGX Spark (GB10, 128 GB unified memory, ARM64),
grouped by model family.

| Directory | Scripts | Contents |
|---|---:|---|
| [speculative-decoding/](speculative-decoding/) | 7 | **MTP and DFlash**, the most technically dense group here |
| [gemma-4/](gemma-4/) | 7 | Gemma 4 family, BF16 / NVFP4 quantisation pairs |
| [gpt-oss/](gpt-oss/) | 4 | GPT-OSS-120B, MXFP4, including two parameterised launchers |
| [embedding/](embedding/) | 3 | Embedding services for GraphRAG / retrieval |
| [glm/](glm/) | 2 | GLM-4.7-Flash, GLM-4-9B |
| [qwen/](qwen/) | 2 | Qwen3-30B-A3B-Thinking, QwQ-32B |
| [domain/](domain/) | 1 | Materials-science model |

`gemma-4/` and `gpt-oss/` hold the baseline configurations **without** speculative
decoding, which makes them the control group for `speculative-decoding/` —
measuring the benefit means running the matching pair against each other.

## Shared conventions

Every script:

- starts through Docker, mounting `~/.cache/huggingface` as a shared model cache
- checks the environment variables it needs and aborts if any are missing
  (`: "${HF_TOKEN:?...}"`)
- serves on `localhost:8000` by default; embedding uses 8001 / 8002 to avoid clashes

```bash
cp ../.env.example ../.env   # fill in HF_TOKEN and VLLM_API_KEY
source ../.env
./gpt-oss/gpt-oss-120b-mxfp4.sh
```

## Memory behaviour on DGX Spark

GB10 uses a **unified memory** architecture: CPU and GPU share 128 GB. This means
`--gpu-memory-utilization` does not mean what it means on a discrete card — set it
too high and you squeeze out the system itself. In practice:

| Model size | Suggested starting point |
|---|---|
| < 1B (embedding) | 0.05 |
| 8B class | 0.25 |
| 26–32B | 0.6 – 0.7 |
| 120B (quantised) | 0.7 – 0.9 |

These are measured starting points, not fixed values — change the context length
or batch size and they need retuning.
