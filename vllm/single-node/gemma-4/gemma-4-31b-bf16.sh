#!/bin/bash
: "${HF_TOKEN:?請先 source .env（可參考 .env.example）}"
export TARGET_MODEL="google/gemma-4-31B-it"
export DRAFTER_MODEL="google/gemma-4-31B-it-assistant"
export DOCKER_IMAGE="vllm/vllm-openai:gemma4-0505-arm64-cu130"

docker run --rm --name vllm_gemma4_31B_bf16_mtp -it \
  --gpus all --ipc host --shm-size 64gb \
  -p 8000:8000 \
  -e HF_TOKEN=$HF_TOKEN \
  -v $HOME/.cache/huggingface/:/root/.cache/huggingface/ \
  $DOCKER_IMAGE \
  --model $TARGET_MODEL \
  --gpu-memory-utilization 0.7 \
  --max-model-len 32768 \
  --max-num-batched-tokens 8192 \
  --reasoning-parser gemma4 \
  --tool-call-parser gemma4 \
  --enable-auto-tool-choice \