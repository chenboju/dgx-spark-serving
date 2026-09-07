#!/bin/bash

# ==========================================
# vLLM 伺服器啟動腳本 (修復官方文件 parser 參數錯誤版)
# ==========================================

# 1. 設定環境變數
: "${HF_TOKEN:?請先 source .env（可參考 .env.example）}"
: "${VLLM_API_KEY:?請先 source .env（可參考 .env.example）}"
export MODEL_HANDLE="zai-org/GLM-4.7-Flash"
export DOCKER_IMAGE="nvcr.io/nvidia/vllm:25.11-py3"

echo "正在啟動 vLLM 伺服器..."
echo "載入模型: $MODEL_HANDLE"
echo "使用映像檔: $DOCKER_IMAGE"
echo "=========================================="

# 2. 執行 Docker 容器
docker run --rm --name vllm_server_GLM47_Flash -it --gpus all \
  --ipc=host \
  -p 8001:8000 \
  -e HF_TOKEN=$HF_TOKEN \
  -e SAFETENSORS_FAST_GPU=1 \
  -v $HOME/.cache/huggingface/:/root/.cache/huggingface/ \
  --entrypoint /bin/bash \
  $DOCKER_IMAGE \
  -c "echo '更新系統與套件...' && \
      apt-get update && apt-get install -y git && \
      echo '安裝最新版 transformers...' && \
      pip install git+https://github.com/huggingface/transformers.git && \
      echo '設定環境變數並啟動 vLLM...' && \
      export HF_HUB_DISABLE_PROGRESS_BARS=1 && \
      vllm serve $MODEL_HANDLE \
      --trust-remote-code \
      --max-num-seqs 2 \
      --quantization fp8 \
      --gpu-memory-utilization 0.8 \
      --served-model-name llm_chat \
      --api-key ${VLLM_API_KEY} \
      --tool-call-parser glm45 \
      --reasoning-parser glm45 \
      --enable-auto-tool-choice \
      --speculative-config.method mtp \
      --speculative-config.num_speculative_tokens 1"