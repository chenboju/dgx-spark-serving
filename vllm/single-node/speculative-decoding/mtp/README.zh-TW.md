[English](README.md) | **繁體中文**

# mtp/ — Multi-Token Prediction

用 Gemma 4 官方的 assistant 模型當 drafter，一次推測 4 個 token。

| 腳本 | Target | Drafter |
|---|---|---|
| `gemma-4-26b-a4b-bf16-mtp.sh` | `google/gemma-4-26B-A4B-it` | `google/gemma-4-26B-A4B-it-assistant` |
| `gemma-4-26b-a4b-nvfp4-mtp.sh` | `nvidia/Gemma-4-26B-A4B-NVFP4` | 同上 |
| `gemma-4-31b-bf16-mtp.sh` | `google/gemma-4-31B-it` | `google/gemma-4-31B-it-assistant` |
| `gemma-4-31b-nvfp4-mtp.sh` | `nvidia/Gemma-4-31B-IT-NVFP4` | 同上 |

組態：

```bash
--speculative-config '{"method": "mtp", "model": "<drafter>", "num_speculative_tokens": 4}'
```

image 統一用 `vllm/vllm-openai:gemma4-0505-arm64-cu130`——ARM64 預覽版，內建 MTP 支援。

## NVFP4 版需要替換 gemma4_mtp.py

量化版跑 MTP 時，image 內的 `gemma4_mtp.py` 有 bug。兩支 NVFP4 腳本會先抓修復版本再掛載進容器：

```bash
wget -qO /tmp/gemma4_mtp.py \
  https://raw.githubusercontent.com/vllm-project/vllm/d8b3826648da6b407f8c55/vllm/model_executor/models/gemma4_mtp.py

docker run ... \
  -v /tmp/gemma4_mtp.py:/usr/local/lib/python3.12/dist-packages/vllm/model_executor/models/gemma4_mtp.py
```

**commit hash 是寫死的，這是刻意的。** 上游還在改這個檔案，鎖住版本才能重現當時的行為；
指向 branch 的話某天上游一改，腳本就會無聲地跑出不同結果。

BF16 版不需要這個補丁。

## 用法

```bash
source ../../../.env
./gemma-4-26b-a4b-nvfp4-mtp.sh
```

不含推測解碼的對照組在 [../../gemma-4/](../../gemma-4/README.zh-TW.md)。
