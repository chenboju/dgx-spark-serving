#!/bin/bash

# ==========================================
# vLLM Embedding Server
# Qwen3-Embedding-8B
# 用途：Microsoft GraphRAG embeddings
# 對照組：qwen3-embedding-0.6b.sh
#
# 與 0.6B 版的差異：
#   - 權重 bf16 約 16GB，0.6B 只要約 1.2GB，
#     所以 gpu-memory-utilization 從 0.05 拉到 0.25
#   - 改用 8002 port，方便與 0.6B 同時啟動做品質/延遲對比
# ==========================================

: "${HF_TOKEN:?請先 source .env（可參考 .env.example）}"
export TARGET_MODEL="Qwen/Qwen3-Embedding-8B"
export SERVED_MODEL_NAME="Qwen3-Embedding-8B"
export DOCKER_IMAGE="vllm/vllm-openai:latest"

echo "正在啟動 vLLM Embedding Server：$TARGET_MODEL"
echo "API: http://localhost:8002/v1/embeddings"
echo "=========================================="

docker run --rm --name vllm_server_Qwen3_Embedding_8B -it \
  --gpus all \
  --ipc host \
  --shm-size 32gb \
  -p 8002:8000 \
  -e HF_TOKEN=$HF_TOKEN \
  -v $HOME/.cache/huggingface/:/root/.cache/huggingface/ \
  $DOCKER_IMAGE \
  --model $TARGET_MODEL \
  --served-model-name $SERVED_MODEL_NAME \
  --runner pooling \
  --host 0.0.0.0 \
  --port 8000 \
  --dtype auto \
  --gpu-memory-utilization 0.25
    # --max-model-len 32768 \
