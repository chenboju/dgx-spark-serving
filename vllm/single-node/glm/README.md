**English** | [繁體中文](README.zh-TW.md)

# glm/ — GLM family

Single-node serving configurations for Zhipu's GLM models on DGX Spark.

| Script | Model | Notes |
|---|---|---|
| `glm-4.7-flash.sh` | `zai-org/GLM-4.7-Flash` | Lightweight fast version, includes FlashAttention-related settings |
| `glm-4-9b-0414.sh` | `zai-org/GLM-4-9B-0414` | 9B general-purpose |

## Usage

```bash
source ../../.env
./glm-4.7-flash.sh
```

Serves on `localhost:8000` with an OpenAI-compatible API.

## Note

The GLM family needs `--trust-remote-code`, because the models ship their own
custom modeling code. That falls outside vLLM's official recipes, which is the
main reason these two scripts exist.
