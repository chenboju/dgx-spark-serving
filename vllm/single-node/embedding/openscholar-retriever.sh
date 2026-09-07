#!/bin/bash

# ==========================================
# Infinity Embedding 伺服器啟動腳本
# ==========================================

: "${HF_TOKEN:?請先 source .env（可參考 .env.example）}"
: "${VLLM_API_KEY:?請先 source .env（可參考 .env.example）}"
export MODEL_HANDLE="OpenSciLM/OpenScholar_Retriever"
export DOCKER_IMAGE="michaelfeil/infinity:latest"

echo "正在啟動 Infinity 伺服器..."
echo "載入模型: $MODEL_HANDLE"
echo "使用映像檔: $DOCKER_IMAGE"
echo "=========================================="

# 執行 Docker 容器
docker run --rm --name infinity_openscholar -it --gpus all \
  -p 8001:7997 \
  -e HF_TOKEN=$HF_TOKEN \
  -v $HOME/.cache/huggingface/:/app/.cache/huggingface/ \
  $DOCKER_IMAGE \
  v2 \
  --model-id "$MODEL_HANDLE" \
  --api-key ${VLLM_API_KEY} \
  --port 7997