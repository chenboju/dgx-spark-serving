#!/bin/bash

# ==========================================
# vLLM 伺服器啟動腳本 (Qwen3.5-35B-A3B 動態升級版)
# ==========================================

# 1. 設定環境變數
: "${HF_TOKEN:?請先 source .env（可參考 .env.example）}"
: "${VLLM_API_KEY:?請先 source .env（可參考 .env.example）}"
export MODEL_HANDLE="Qwen/Qwen3-30B-A3B-Thinking-2507"

# 關鍵修改 1：改用 vLLM 官方最新的映像檔
export DOCKER_IMAGE="nvcr.io/nvidia/vllm:26.02-py3"

echo "正在啟動 vLLM 伺服器 (自動升級 transformers)..."
echo "載入模型: $MODEL_HANDLE"
echo "使用映像檔: $DOCKER_IMAGE"
echo "=========================================="

# 關鍵修改 2：加入 --entrypoint 並透過 bash -c 先升級套件再啟動 vLLM
docker run --rm --name vllm_server_Qwen3_30B_FP8 -it --gpus all \
  -p 8001:8000 \
  -e HF_TOKEN=$HF_TOKEN \
  -v $HOME/.cache/huggingface/:/root/.cache/huggingface/ \
  $DOCKER_IMAGE \
  vllm serve "$MODEL_HANDLE" \
  --trust-remote-code \
  --max-num-seqs 2 \
  --dtype bfloat16 \
  --quantization fp8 \
  --kv-cache-dtype fp8 \
  --gpu-memory-utilization 0.7 \
  --served-model-name llm_chat \
  --api-key ${VLLM_API_KEY} \
