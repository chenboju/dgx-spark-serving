#!/bin/bash

# ==========================================
# vLLM 伺服器啟動腳本
# openai/gpt-oss-120b + DFlash (speculative decoding)
# Target: openai/gpt-oss-120b
# Drafter: z-lab/gpt-oss-120b-DFlash
# ==========================================
: "${HF_TOKEN:?請先 source .env（可參考 .env.example）}"
export TARGET_MODEL="openai/gpt-oss-120b"
export DRAFTER_MODEL="z-lab/gpt-oss-120b-DFlash"
export DOCKER_IMAGE="vllm/vllm-openai:nightly"
export TIKTOKEN_CACHE_DIR="$HOME/tiktoken_encodings"

echo "1. 正在拉取 Docker image：$DOCKER_IMAGE ..."
docker pull "$DOCKER_IMAGE"

echo "2. 正在準備 tiktoken vocab（harmony tokenizer 需要）..."
# openai-harmony 0.0.8 透過 TIKTOKEN_ENCODINGS_BASE 讀取 vocab 時，
# 是直接找 "$TIKTOKEN_ENCODINGS_BASE/o200k_base.tiktoken" 這個原始檔名
# （用 strace 追蹤 openat() 系統呼叫確認，不是 tiktoken SHA1 雜湊檔名）
mkdir -p "$TIKTOKEN_CACHE_DIR"
TIKTOKEN_FILE="$TIKTOKEN_CACHE_DIR/o200k_base.tiktoken"
if [ ! -f "$TIKTOKEN_FILE" ]; then
  curl -L "https://openaipublic.blob.core.windows.net/encodings/o200k_base.tiktoken" \
    -o "$TIKTOKEN_FILE"
else
  echo "tiktoken vocab 已存在：$TIKTOKEN_FILE"
fi

echo "3. 正在啟動 vLLM 伺服器..."
echo "=========================================="

docker run --rm --name vllm_server_gptoss120b_DFlash -it \
  --gpus all --ipc host --shm-size 64gb \
  -p 8000:8000 \
  -e HF_TOKEN \
  -e TIKTOKEN_RS_CACHE_DIR="/tiktoken_encodings" \
  -e TIKTOKEN_ENCODINGS_BASE="/tiktoken_encodings" \
  -v $HOME/.cache/huggingface/:/root/.cache/huggingface/ \
  -v "$TIKTOKEN_CACHE_DIR:/tiktoken_encodings" \
  $DOCKER_IMAGE \
  $TARGET_MODEL \
  --gpu-memory-utilization 0.7 \
  --max-model-len 32768 \
  --speculative-config "{\"method\":\"dflash\",\"model\":\"$DRAFTER_MODEL\",\"num_speculative_tokens\":2}"
