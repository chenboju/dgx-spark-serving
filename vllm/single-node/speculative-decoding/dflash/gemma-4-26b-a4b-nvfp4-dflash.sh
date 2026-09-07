#!/bin/bash

# ==========================================
# 步驟 1: 快速建置 DGX Spark 專用的 ARM64 DFlash Image (只要約 5~10 秒)
# ==========================================
echo "正在透過 Python Source Overlay 快速建置 ARM64 DFlash Image..."
docker build -t vllm-dflash-arm64-local - <<'EOF'
FROM vllm/vllm-openai:gemma4-0505-arm64-cu130
RUN apt-get update && apt-get install -y git && rm -rf /var/lib/apt/lists/*
RUN SITE_PKG=$(python3 -c "import site; print(site.getsitepackages()[0])") \
    && git clone https://github.com/vllm-project/vllm.git /tmp/vllm-src \
    && cd /tmp/vllm-src \
    && git fetch origin pull/41703/head:dflash-pr \
    && git checkout dflash-pr \
    && cp -r /tmp/vllm-src/vllm/* "${SITE_PKG}/vllm/" \
    && rm -rf /tmp/vllm-src
EOF

# ==========================================
# 步驟 2: 啟動 vLLM 伺服器 (NVFP4 + DFlash)
# ==========================================
: "${HF_TOKEN:?請先 source .env（可參考 .env.example）}"
export TARGET_MODEL="nvidia/Gemma-4-26B-A4B-NVFP4"

echo "建置完成！正在啟動 vLLM 伺服器 (包含 NVFP4 與 DFlash 效能優化參數)..."
echo "=========================================="

docker run --rm --name vllm_server_Gemma4_NVFP4_DFlash -it \
  --gpus all \
  --ipc=host \
  --shm-size=64gb \
  -p 8000:8000 \
  -e HF_TOKEN=$HF_TOKEN \
  -v $HOME/.cache/huggingface/:/root/.cache/huggingface/ \
  vllm-dflash-arm64-local \
  --model $TARGET_MODEL \
  --gpu-memory-utilization 0.7 \
  --max-model-len 48000 \
  --max-num-batched-tokens 32768 \
  --reasoning-parser gemma4 \
  --tool-call-parser gemma4 \
  --enable-auto-tool-choice \
  --attention-backend triton_attn \
  --speculative-config '{"method": "dflash", "model": "z-lab/gemma-4-26B-A4B-it-DFlash", "num_speculative_tokens": 15, "attention_backend": "flash_attn"}' \
  --trust-remote-code