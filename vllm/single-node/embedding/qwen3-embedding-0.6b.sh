#!/bin/bash

# ==========================================
# vLLM Embedding Server
# Qwen3-Embedding-0.6B
# 用途：Microsoft GraphRAG embeddings
# 對照組：qwen3-embedding-8b.sh
# ==========================================

: "${HF_TOKEN:?請先 source .env（可參考 .env.example）}"
export TARGET_MODEL="Qwen/Qwen3-Embedding-0.6B"
export SERVED_MODEL_NAME="Qwen3-Embedding-0.6B"
export DOCKER_IMAGE="vllm/vllm-openai:latest"

echo "正在啟動 vLLM Embedding Server：$TARGET_MODEL"
echo "API: http://localhost:8001/v1/embeddings"
echo "=========================================="

docker run --rm --name vllm_server_Qwen3_Embedding_0.6B -it \
  --gpus all \
  --ipc host \
  --shm-size 32gb \
  -p 8001:8000 \
  -e HF_TOKEN=$HF_TOKEN \
  -v $HOME/.cache/huggingface/:/root/.cache/huggingface/ \
  $DOCKER_IMAGE \
  --model $TARGET_MODEL \
  --served-model-name $SERVED_MODEL_NAME \
  --runner pooling \
  --host 0.0.0.0 \
  --port 8000 \
  --dtype auto \
  --gpu-memory-utilization 0.05
    # --max-model-len 8192 \