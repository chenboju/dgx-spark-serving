#!/bin/bash

# ==========================================
# vLLM 伺服器啟動腳本
# nvidia/Gemma-4-26B-A4B-NVFP4 + MTP
# 純文字模式，不啟用多模態
# ==========================================

export TARGET_MODEL="nvidia/Gemma-4-26B-A4B-NVFP4"
export DRAFTER_MODEL="google/gemma-4-26B-A4B-it-assistant"
export DOCKER_IMAGE="vllm/vllm-openai:gemma4-0505-arm64-cu130"

echo "1. 正在下載修復版的 gemma4_mtp.py..."
wget -qO /tmp/gemma4_mtp.py https://raw.githubusercontent.com/vllm-project/vllm/d8b3826648da6b407f8c55/vllm/model_executor/models/gemma4_mtp.py

echo "2. 正在啟動 vLLM 伺服器..."
echo "=========================================="

docker run --rm --name vllm_server_Gemma4_NVFP4_MTP -it \
  --gpus all --ipc host --shm-size 64gb \
  -p 8000:8000 \
  -e HF_TOKEN \
  -v $HOME/.cache/huggingface/:/root/.cache/huggingface/ \
  -v /tmp/gemma4_mtp.py:/usr/local/lib/python3.12/dist-packages/vllm/model_executor/models/gemma4_mtp.py \
  $DOCKER_IMAGE \
  $TARGET_MODEL \
  --gpu-memory-utilization 0.6 \
  --max-model-len 96000 \
  --max-num-batched-tokens 192000 \
  --max-num-seqs 12 \
  --limit-mm-per-prompt '{"image":0,"audio":0}' \
  --reasoning-parser gemma4 \
  --speculative-config "{\"method\":\"mtp\",\"model\":\"$DRAFTER_MODEL\",\"num_speculative_tokens\":4}"