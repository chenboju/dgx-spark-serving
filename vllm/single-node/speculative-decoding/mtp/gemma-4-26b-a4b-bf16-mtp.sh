#!/bin/bash

# ==========================================
# vLLM 伺服器啟動腳本 (Gemma-4-26B-A4B-it MTP 啟用版)
# ==========================================

: "${HF_TOKEN:?請先 source .env（可參考 .env.example）}"
export HF_MODEL_HANDLE="google/gemma-4-26B-A4B-it"
# 修改 1：使用針對 DGX Spark (ARM64) 且包含 MTP 支援的預覽版 Image
export DOCKER_IMAGE="vllm/vllm-openai:gemma4-0505-arm64-cu130"

echo "正在啟動 vLLM 伺服器 (包含 MTP 效能優化參數)..."
echo "=========================================="

docker run --rm --name vllm_server_Gemma4 -it \
  --gpus all \
  -p 8000:8000 \
  -e HF_TOKEN=$HF_TOKEN \
  -v $HOME/.cache/huggingface/:/root/.cache/huggingface/ \
  $DOCKER_IMAGE \
  --model $HF_MODEL_HANDLE \
  --gpu-memory-utilization 0.7 \
  --max-model-len 48000 \
  --reasoning-parser gemma4 \
  --tool-call-parser gemma4 \
  --enable-auto-tool-choice \
  --max-num-batched-tokens 8192 \
  --speculative-config '{"method": "mtp", "model":"google/gemma-4-26B-A4B-it-assistant", "num_speculative_tokens": 4}'