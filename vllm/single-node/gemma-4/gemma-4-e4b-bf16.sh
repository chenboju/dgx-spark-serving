#!/bin/bash

# ==========================================
# vLLM 伺服器啟動腳本 (Gemma-4-26B-A4B-it 效能優化版)
# ==========================================

: "${HF_TOKEN:?請先 source .env（可參考 .env.example）}"
export HF_MODEL_HANDLE="google/gemma-4-E4B-it"
export DOCKER_IMAGE="vllm/vllm-openai:gemma4-cu130"

echo "正在啟動 vLLM 伺服器 (包含效能優化參數)..."
echo "=========================================="

# 啟動指令：
# 1. 加上 --shm-size 16g 確保多 GPU 通訊正常
# 2. 參數直接附加在 $HF_MODEL_HANDLE 之後
docker run --rm --name vllm_server_Gemma4 -it \
  --gpus all \
  -p 8000:8000 \
  -e HF_TOKEN=$HF_TOKEN \
  -v $HOME/.cache/huggingface/:/root/.cache/huggingface/ \
  $DOCKER_IMAGE \
  $HF_MODEL_HANDLE \
  --gpu-memory-utilization 0.6 \
  --max-model-len 48000 \
  --reasoning-parser gemma4 \
  --tool-call-parser gemma4\
  --enable-auto-tool-choice
  #   --kv-cache-dtype fp8 \
  #   --tensor-parallel-size 2 \
  #   --shm-size 16g \