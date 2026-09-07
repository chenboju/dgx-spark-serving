#!/bin/bash

# ==========================================
# vLLM 伺服器啟動腳本
# google/diffusiongemma-26B-A4B-it
# 用途：Microsoft GraphRAG indexing
# ==========================================

: "${HF_TOKEN:?請先 source .env（可參考 .env.example）}"
export TARGET_MODEL="google/diffusiongemma-26B-A4B-it"
export DOCKER_IMAGE="vllm/vllm-openai:gemma"

echo "正在啟動 vLLM 伺服器：$TARGET_MODEL"
echo "用途：Microsoft GraphRAG indexing"
echo "=========================================="

docker run --rm --name vllm_server_DiffusionGemma_Google_GraphRAG -it \
  --gpus all \
  --ipc host \
  --shm-size 64gb \
  -p 8000:8000 \
  -e HF_TOKEN=$HF_TOKEN \
  -v $HOME/.cache/huggingface/:/root/.cache/huggingface/ \
  $DOCKER_IMAGE \
  --model $TARGET_MODEL \
  --served-model-name $TARGET_MODEL \
  --trust-remote-code \
  --max-model-len 32768 \
  --max-num-seqs 1 \
  --max-num-batched-tokens 8192 \
  --gpu-memory-utilization 0.75 \
  --attention-backend TRITON_ATTN \
  --generation-config vllm \
  --hf-overrides '{"diffusion_sampler":"entropy_bound","diffusion_entropy_bound":0.1}' \
  --diffusion-config '{"canvas_length":256}' \
  --enable-chunked-prefill \
  --enable-prefix-caching \
  --limit-mm-per-prompt '{"image":0,"audio":0}' \
  --host 0.0.0.0 \
  --port 8000