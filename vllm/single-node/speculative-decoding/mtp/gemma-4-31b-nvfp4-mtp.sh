#!/bin/bash
: "${HF_TOKEN:?請先 source .env（可參考 .env.example）}"
export TARGET_MODEL="nvidia/Gemma-4-31B-IT-NVFP4"
export DRAFTER_MODEL="google/gemma-4-31B-it-assistant"
export DOCKER_IMAGE="vllm/vllm-openai:gemma4-0505-arm64-cu130"

# 下載 Bug 修復檔 (NVFP4 量化版必備)
wget -qO /tmp/gemma4_mtp.py https://raw.githubusercontent.com/vllm-project/vllm/d8b3826648da6b407f8c55/vllm/model_executor/models/gemma4_mtp.py

docker run --rm --name vllm_gemma4_31B_nvfp4_mtp -it \
  --gpus all --ipc host --shm-size 64gb \
  -p 8000:8000 \
  -e HF_TOKEN=$HF_TOKEN \
  -v $HOME/.cache/huggingface/:/root/.cache/huggingface/ \
  -v /tmp/gemma4_mtp.py:/usr/local/lib/python3.12/dist-packages/vllm/model_executor/models/gemma4_mtp.py \
  $DOCKER_IMAGE \
  --model $TARGET_MODEL \
  --gpu-memory-utilization 0.6 \
  --max-model-len 128000 \
  --max-num-batched-tokens 8192 \
  --reasoning-parser gemma4 \
  --tool-call-parser gemma4 \
  --enable-auto-tool-choice \
  --speculative-config '{"method": "mtp", "model":"google/gemma-4-31B-it-assistant", "num_speculative_tokens": 4}'