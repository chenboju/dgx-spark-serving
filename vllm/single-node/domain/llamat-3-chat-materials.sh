#!/bin/bash

# ==========================================
# vLLM 伺服器啟動腳本 (m3rg-iitd/llamat-3-chat)
# ==========================================

# 1. 設定環境變數
: "${HF_TOKEN:?請先 source .env（可參考 .env.example）}"
export MODEL_HANDLE="m3rg-iitd/llamat-3-chat"
export DOCKER_IMAGE="nvcr.io/nvidia/vllm:26.04-py3"

echo "正在啟動 vLLM 伺服器..."
echo "載入模型: $MODEL_HANDLE"
echo "使用映像檔: $DOCKER_IMAGE"
echo "=========================================="

# 2. 執行 Docker 容器
docker run --rm --name vllm_server_llamat_3 -it --gpus all \
  -p 8000:8000 \
  -e HF_TOKEN=$HF_TOKEN \
  -v $HOME/.cache/huggingface/:/root/.cache/huggingface/ \
  $DOCKER_IMAGE \
  vllm serve "$MODEL_HANDLE" \
  --trust-remote-code \
  --dtype bfloat16 \
  --gpu-memory-utilization 0.7 \
  --served-model-name llamat-3-chat \
#   --max-model-len 8192