[English](README.md) | **繁體中文**

# glm/ — GLM 系列

智譜 GLM 模型在 DGX Spark 上的單機服務組態。

| 腳本 | 模型 | 說明 |
|---|---|---|
| `glm-4.7-flash.sh` | `zai-org/GLM-4.7-Flash` | 輕量快速版，含 FlashAttention 相關設定 |
| `glm-4-9b-0414.sh` | `zai-org/GLM-4-9B-0414` | 9B 通用版 |

## 用法

```bash
source ../../.env
./glm-4.7-flash.sh
```

服務起在 `localhost:8000`，OpenAI 相容 API。

## 備註

GLM 系列需要 `--trust-remote-code`，因為模型自帶客製化的 modeling 程式碼。
這在 vLLM 官方 recipe 之外，是這兩支腳本存在的主要原因。
