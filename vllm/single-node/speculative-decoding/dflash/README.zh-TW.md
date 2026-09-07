[English](README.md) | **繁體中文**

# dflash/ — DFlash

用 z-lab 訓練的專用 drafter 做推測解碼。drafter 是針對特定 target 模型訓練的，
接受率高，所以敢一次猜到 15 個 token。

| 腳本 | Target | Drafter | tokens |
|---|---|---|---:|
| `gemma-4-26b-a4b-bf16-dflash.sh` | `google/gemma-4-26B-A4B-it` | `z-lab/gemma-4-26B-A4B-it-DFlash` | 15 |
| `gemma-4-26b-a4b-nvfp4-dflash.sh` | `nvidia/Gemma-4-26B-A4B-NVFP4` | 同上 | 15 |
| `gpt-oss-120b-dflash.sh` | `openai/gpt-oss-120b` | `z-lab/gpt-oss-120b-DFlash` | 2 |

## 兩個 attention backend

Gemma 的兩支腳本刻意讓 target 和 draft 用不同的 backend：

```bash
--attention-backend triton_attn                    # target 模型
--speculative-config '{..., "attention_backend": "flash_attn"}'   # drafter
```

target 走 Triton（ARM64 上相容性較好），drafter 走 FlashAttention（短序列上更快）。

## Gemma 版：從未合併的 PR 建 image

DFlash 支援當時還停在 vLLM 的 PR #41703，沒有進 release。兩支 Gemma 腳本的做法是
**Python source overlay**——不重編整包 vLLM，只把 PR 的 Python 原始碼疊到現成 image 的
site-packages 上：

```dockerfile
FROM vllm/vllm-openai:gemma4-0505-arm64-cu130
RUN SITE_PKG=$(python3 -c "import site; print(site.getsitepackages()[0])") \
    && git clone https://github.com/vllm-project/vllm.git /tmp/vllm-src \
    && cd /tmp/vllm-src \
    && git fetch origin pull/41703/head:dflash-pr \
    && git checkout dflash-pr \
    && cp -r /tmp/vllm-src/vllm/* "${SITE_PKG}/vllm/" \
    && rm -rf /tmp/vllm-src
```

建置時間 **5~10 秒**，而不是在 ARM64 上從頭編譯 vLLM 的數小時。前提是 PR 只動 Python 層、
沒改 CUDA kernel——這個判斷成立才能這樣做。

腳本會自動建好 `vllm-dflash-arm64-local` 這個 image 再啟動，不需要手動先 build。

## GPT-OSS 版：tiktoken vocab 的坑

`gpt-oss-120b-dflash.sh` 用官方 nightly image，不需自建，但要處理 tokenizer 問題：

openai-harmony 載入 vocab 時找的是**原始檔名** `o200k_base.tiktoken`，而不是 tiktoken
慣用的 SHA1 雜湊檔名。這是用 `strace` 追 `openat()` 系統呼叫確認的。

所以掛載進容器的檔案必須照原始檔名準備：

```bash
curl -L "https://openaipublic.blob.core.windows.net/encodings/o200k_base.tiktoken" \
  -o "$TIKTOKEN_CACHE_DIR/o200k_base.tiktoken"

docker run ... \
  -e TIKTOKEN_ENCODINGS_BASE="/tiktoken_encodings" \
  -v "$TIKTOKEN_CACHE_DIR:/tiktoken_encodings"
```

## 用法

```bash
source ../../../.env
./gemma-4-26b-a4b-nvfp4-dflash.sh    # 會先自動 build image
```

不含推測解碼的對照組在 [../../gemma-4/](../../gemma-4/README.zh-TW.md) 與 [../../gpt-oss/](../../gpt-oss/README.zh-TW.md)。
