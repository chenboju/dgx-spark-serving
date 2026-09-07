#!/bin/bash
set -euo pipefail

# =========================================================
# GPT-OSS-120B on DGX Spark / DGX / vLLM Docker
# OpenAI-compatible API: http://localhost:8000/v1
# =========================================================

# -------------------------------
# 基本設定
# -------------------------------

MODEL_ID="openai/gpt-oss-120b"
SERVED_MODEL_NAME="openai/gpt-oss-120b"

PORT="${PORT:-8000}"
CONTAINER_NAME="${CONTAINER_NAME:-vllm_server_gptoss120b}"

# 模型與 cache 存放位置
MODEL_DIR="${MODEL_DIR:-$HOME/models/gpt-oss-120b}"
HF_CACHE_DIR="${HF_CACHE_DIR:-$HOME/.cache/huggingface}"
TIKTOKEN_CACHE_DIR="${TIKTOKEN_CACHE_DIR:-$HOME/tiktoken_encodings}"

# 優先使用本機已存在的 vllm-node
# 如果沒有 vllm-node，會自動 pull 備用 image
LOCAL_IMAGE="${LOCAL_IMAGE:-vllm-node}"
FALLBACK_IMAGE="${FALLBACK_IMAGE:-sparkarena/spark-vllm-docker:mxfp4}"

# vLLM 參數
GPU_MEMORY_UTILIZATION="${GPU_MEMORY_UTILIZATION:-0.90}"
MAX_MODEL_LEN="${MAX_MODEL_LEN:-48000}"
MAX_NUM_BATCHED_TOKENS="${MAX_NUM_BATCHED_TOKENS:-8192}"

# 是否先把模型下載到 MODEL_DIR
# 1 = 先下載到本地 /model
# 0 = 直接讓 vLLM 從 Hugging Face cache 載入
DOWNLOAD_MODEL="${DOWNLOAD_MODEL:-1}"

# 是否啟用 tool calling
ENABLE_TOOLS="${ENABLE_TOOLS:-1}"

# -------------------------------
# 檢查 HF_TOKEN
# -------------------------------

if [ -z "${HF_TOKEN:-}" ]; then
  echo "錯誤：請先設定 Hugging Face Token。"
  echo ""
  echo "請執行："
  echo "  export HF_TOKEN=\"你的_HuggingFace_Token\""
  echo ""
  echo "不要把 HF_TOKEN 寫死在 .sh 檔案裡。"
  exit 1
fi

# -------------------------------
# 建立資料夾
# -------------------------------

mkdir -p "$MODEL_DIR"
mkdir -p "$HF_CACHE_DIR"
mkdir -p "$TIKTOKEN_CACHE_DIR"

echo "=========================================="
echo "GPT-OSS-120B vLLM 啟動腳本"
echo "MODEL_ID: $MODEL_ID"
echo "MODEL_DIR: $MODEL_DIR"
echo "HF_CACHE_DIR: $HF_CACHE_DIR"
echo "PORT: $PORT"
echo "=========================================="

# -------------------------------
# 檢查 Docker
# -------------------------------

if ! command -v docker >/dev/null 2>&1; then
  echo "錯誤：找不到 docker，請先安裝 Docker。"
  exit 1
fi

# -------------------------------
# 選擇 Docker image
# -------------------------------

IMAGE_TO_USE="$LOCAL_IMAGE"

if docker image inspect "$LOCAL_IMAGE" >/dev/null 2>&1; then
  echo "找到本機 image：$LOCAL_IMAGE"
else
  echo "找不到本機 image：$LOCAL_IMAGE"
  echo "改用備用 image：$FALLBACK_IMAGE"
  echo "正在 docker pull..."
  docker pull "$FALLBACK_IMAGE"
  IMAGE_TO_USE="$FALLBACK_IMAGE"
fi

echo "使用 Docker image：$IMAGE_TO_USE"

# -------------------------------
# 下載 tiktoken vocab
# GPT-OSS / harmony tokenizer 可能需要 o200k_base.tiktoken
# -------------------------------

TIKTOKEN_HASH="fb374d419588a4632f3f557e76b4b70aebbca790"
TIKTOKEN_FILE="$TIKTOKEN_CACHE_DIR/$TIKTOKEN_HASH"

if [ ! -f "$TIKTOKEN_FILE" ]; then
  echo "下載 tiktoken vocab 到：$TIKTOKEN_FILE"

  if command -v curl >/dev/null 2>&1; then
    curl -L \
      "https://openaipublic.blob.core.windows.net/encodings/o200k_base.tiktoken" \
      -o "$TIKTOKEN_FILE"
  elif command -v wget >/dev/null 2>&1; then
    wget \
      "https://openaipublic.blob.core.windows.net/encodings/o200k_base.tiktoken" \
      -O "$TIKTOKEN_FILE"
  else
    echo "警告：找不到 curl 或 wget，略過 tiktoken vocab 下載。"
    echo "如果啟動時遇到 tokenizer / HarmonyError，請手動下載 o200k_base.tiktoken。"
  fi
else
  echo "tiktoken vocab 已存在：$TIKTOKEN_FILE"
fi

# -------------------------------
# 如果容器已存在，先移除
# -------------------------------

if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  echo "移除既有 container：$CONTAINER_NAME"
  docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
fi

# -------------------------------
# 下載模型到本地 MODEL_DIR
# -------------------------------

if [ "$DOWNLOAD_MODEL" = "1" ]; then
  if [ -f "$MODEL_DIR/config.json" ]; then
    echo "模型看起來已經存在，略過下載：$MODEL_DIR"
  else
    echo "開始下載模型到：$MODEL_DIR"
    echo "這一步會很久，GPT-OSS-120B 檔案很大。"

    docker run --rm \
      --network=host \
      -e HF_TOKEN="$HF_TOKEN" \
      -e HUGGING_FACE_HUB_TOKEN="$HF_TOKEN" \
      -v "$MODEL_DIR:/model" \
      -v "$HF_CACHE_DIR:/root/.cache/huggingface" \
      "$IMAGE_TO_USE" \
      bash -lc "
        python3 - <<'PY'
from huggingface_hub import snapshot_download
import os

model_id = '${MODEL_ID}'
token = os.environ.get('HF_TOKEN')

snapshot_download(
    repo_id=model_id,
    local_dir='/model',
    token=token,
    local_dir_use_symlinks=False
)

print('模型下載完成：/model')
PY
      "
  fi

  MODEL_ARG="/model"
else
  echo "DOWNLOAD_MODEL=0，將直接用 Hugging Face model id 啟動：$MODEL_ID"
  MODEL_ARG="$MODEL_ID"
fi

# -------------------------------
# 組合 vLLM 啟動參數
# -------------------------------

VLLM_ARGS=(
  "vllm" "serve" "$MODEL_ARG"
  "--served-model-name" "$SERVED_MODEL_NAME"
  "--host" "0.0.0.0"
  "--port" "$PORT"
  "--gpu-memory-utilization" "$GPU_MEMORY_UTILIZATION"
  "--max-model-len" "$MAX_MODEL_LEN"
  "--max-num-batched-tokens" "$MAX_NUM_BATCHED_TOKENS"
)

if [ "$ENABLE_TOOLS" = "1" ]; then
  VLLM_ARGS+=(
    "--enable-auto-tool-choice"
    "--tool-call-parser" "openai"
  )
fi

# 注意：
# 先不要加 --reasoning-parser openai_gptoss
# 否則一般 OpenAI client 可能讀到 content: null。
#
# 先不要加 --enforce-eager
# 這會讓推論速度大幅下降。

# -------------------------------
# 啟動 vLLM Server
# -------------------------------

echo "=========================================="
echo "啟動 vLLM Server..."
echo "API Base URL: http://localhost:${PORT}/v1"
echo "Served model: ${SERVED_MODEL_NAME}"
echo "=========================================="

docker run --rm --name "$CONTAINER_NAME" -it \
  --privileged \
  --gpus all \
  --network=host \
  --ipc=host \
  --shm-size=64g \
  -e HF_TOKEN="$HF_TOKEN" \
  -e HUGGING_FACE_HUB_TOKEN="$HF_TOKEN" \
  -e HF_HUB_ENABLE_HF_TRANSFER=1 \
  -e TIKTOKEN_RS_CACHE_DIR="/tiktoken_encodings" \
  -e TIKTOKEN_ENCODINGS_BASE="/tiktoken_encodings" \
  -v "$MODEL_DIR:/model" \
  -v "$HF_CACHE_DIR:/root/.cache/huggingface" \
  -v "$TIKTOKEN_CACHE_DIR:/tiktoken_encodings" \
  "$IMAGE_TO_USE" \
  "${VLLM_ARGS[@]}"