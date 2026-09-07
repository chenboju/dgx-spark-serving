#!/bin/bash

# ==========================================
# vLLM 伺服器啟動腳本
# ==========================================

# 1. 設定環境變數
: "${HF_TOKEN:?請先 source .env（可參考 .env.example）}"
: "${VLLM_API_KEY:?請先 source .env（可參考 .env.example）}"
export MODEL_HANDLE="openai/gpt-oss-120b"
export DOCKER_IMAGE="nvcr.io/nvidia/vllm:25.11-py3"

echo "正在啟動 vLLM 伺服器..."
echo "載入模型: $MODEL_HANDLE"
echo "使用映像檔: $DOCKER_IMAGE"
echo "=========================================="

# 2. 執行 Docker 容器
docker run --rm --name vllm_server_gptoss_120b -it --gpus all \
  -p 8001:8000 \
  -e HF_TOKEN=$HF_TOKEN \
  -v $HOME/.cache/huggingface/:/root/.cache/huggingface/ \
  $DOCKER_IMAGE \
  vllm serve "$MODEL_HANDLE" \
  --trust_remote_code \
  --max-num-seqs 2 \
  --quantization mxfp4 \
  --gpu-memory-utilization 0.8 \
  --served-model-name llm_chat \
  --api-key ${VLLM_API_KEY}