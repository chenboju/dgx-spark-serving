#!/bin/bash

# ==========================================
# vLLM 伺服器啟動腳本：GPT-OSS-120B
# 最簡單可跑版本
# API: http://localhost:8000/v1
# ==========================================

# 如果模型已經下載在 ~/.cache/huggingface，可以不一定需要 HF_TOKEN
# 但保留 HF_TOKEN 比較保險
export HF_TOKEN="${HF_TOKEN:-}"

export TARGET_MODEL="openai/gpt-oss-120b"
export SERVED_MODEL_NAME="openai/gpt-oss-120b"
export DOCKER_IMAGE="nvcr.io/nvidia/vllm:26.04-py3"

# 先用保守參數，避免記憶體不足
export GPU_MEMORY_UTILIZATION="0.7"
export MAX_MODEL_LEN="81920"

echo "正在啟動 vLLM 伺服器：GPT-OSS-120B"
echo "Model: $TARGET_MODEL"
echo "Docker Image: $DOCKER_IMAGE"
echo "GPU Memory Utilization: $GPU_MEMORY_UTILIZATION"
echo "Max Model Len: $MAX_MODEL_LEN"
echo "=========================================="

docker run --rm --name vllm_gptoss_120b -it \
  --gpus all \
  --ipc=host \
  --shm-size=64gb \
  -p 8000:8000 \
  -e HF_TOKEN=$HF_TOKEN \
  -e HF_HOME=/root/.cache/huggingface \
  -e HF_HUB_OFFLINE=1 \
  -e TRANSFORMERS_OFFLINE=1 \
  -v $HOME/.cache/huggingface/:/root/.cache/huggingface/ \
  $DOCKER_IMAGE \
  vllm serve $TARGET_MODEL \
    --served-model-name $SERVED_MODEL_NAME \
    --host 0.0.0.0 \
    --port 8000 \
    --gpu-memory-utilization $GPU_MEMORY_UTILIZATION \
    --max-model-len $MAX_MODEL_LEN \