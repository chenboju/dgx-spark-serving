#!/bin/bash
set -euo pipefail

# =========================================================
# GPT-OSS-120B on DGX Spark / vLLM
# 使用已下載的 Hugging Face cache，不重新下載模型
# API: http://localhost:8000/v1
# =========================================================

# -------------------------------
# 基本設定
# -------------------------------

IMAGE_NAME="${IMAGE_NAME:-vllm-node}"
CONTAINER_NAME="${CONTAINER_NAME:-vllm_server_gptoss120b}"

MODEL_CACHE_NAME="models--openai--gpt-oss-120b"
SERVED_MODEL_NAME="${SERVED_MODEL_NAME:-openai/gpt-oss-120b}"

PORT="${PORT:-8000}"

HOST_HF_CACHE="${HOST_HF_CACHE:-$HOME/.cache/huggingface}"
HOST_HF_HUB="${HOST_HF_CACHE}/hub"
HOST_MODEL_CACHE="${HOST_HF_HUB}/${MODEL_CACHE_NAME}"

TIKTOKEN_CACHE_DIR="${TIKTOKEN_CACHE_DIR:-$HOME/tiktoken_encodings}"

GPU_MEMORY_UTILIZATION="${GPU_MEMORY_UTILIZATION:-0.90}"
MAX_MODEL_LEN="${MAX_MODEL_LEN:-48000}"
MAX_NUM_BATCHED_TOKENS="${MAX_NUM_BATCHED_TOKENS:-8192}"

# 是否啟用 tool calling
ENABLE_TOOLS="${ENABLE_TOOLS:-1}"

# DGX Spark / GB10 / SM121 建議先啟用
USE_DGX_SPARK_FIX="${USE_DGX_SPARK_FIX:-1}"

# -------------------------------
# 顯示設定
# -------------------------------

echo "=========================================="
echo "GPT-OSS-120B vLLM 啟動腳本"
echo "Docker image: ${IMAGE_NAME}"
echo "HF cache: ${HOST_HF_CACHE}"
echo "Model cache: ${HOST_MODEL_CACHE}"
echo "Port: ${PORT}"
echo "Max model len: ${MAX_MODEL_LEN}"
echo "Max batched tokens: ${MAX_NUM_BATCHED_TOKENS}"
echo "=========================================="

# -------------------------------
# 檢查 Docker
# -------------------------------

if ! command -v docker >/dev/null 2>&1; then
  echo "錯誤：找不到 docker，請先安裝 Docker。"
  exit 1
fi

# -------------------------------
# 檢查 Docker image
# -------------------------------

if ! docker image inspect "${IMAGE_NAME}" >/dev/null 2>&1; then
  echo "錯誤：找不到 Docker image：${IMAGE_NAME}"
  echo ""
  echo "請先確認你是否已經有 GPT-OSS 可用的 vLLM image："
  echo "  docker images"
  echo ""
  echo "如果你的 image 名稱不是 vllm-node，可以這樣執行："
  echo "  IMAGE_NAME=你的_image_name ./gptoss_120b_cache_vllm.sh"
  echo ""
  echo "注意：不建議直接用 Gemma4 的 vllm-dflash-arm64-local 跑 GPT-OSS-120B。"
  exit 1
fi

# -------------------------------
# 檢查模型 cache 是否存在
# -------------------------------

if [ ! -d "${HOST_MODEL_CACHE}" ]; then
  echo "錯誤：找不到模型 cache：${HOST_MODEL_CACHE}"
  echo ""
  echo "你目前應該要有："
  echo "  ${HOST_HF_HUB}/${MODEL_CACHE_NAME}"
  exit 1
fi

if [ ! -d "${HOST_MODEL_CACHE}/snapshots" ]; then
  echo "錯誤：找不到 snapshots 目錄：${HOST_MODEL_CACHE}/snapshots"
  exit 1
fi

HOST_SNAPSHOT_DIR="$(ls -td "${HOST_MODEL_CACHE}/snapshots/"* 2>/dev/null | head -n 1)"

if [ -z "${HOST_SNAPSHOT_DIR}" ] || [ ! -d "${HOST_SNAPSHOT_DIR}" ]; then
  echo "錯誤：找不到 GPT-OSS-120B snapshot。"
  echo "請檢查：${HOST_MODEL_CACHE}/snapshots/"
  exit 1
fi

SNAPSHOT_ID="$(basename "${HOST_SNAPSHOT_DIR}")"

# container 內部對應路徑
CONTAINER_MODEL_PATH="/root/.cache/huggingface/hub/${MODEL_CACHE_NAME}/snapshots/${SNAPSHOT_ID}"

echo "找到模型 snapshot："
echo "Host:      ${HOST_SNAPSHOT_DIR}"
echo "Container: ${CONTAINER_MODEL_PATH}"
echo "=========================================="

# -------------------------------
# tiktoken cache
# GPT-OSS / harmony tokenizer 可能需要 o200k_base.tiktoken
# -------------------------------

mkdir -p "${TIKTOKEN_CACHE_DIR}"

TIKTOKEN_HASH="fb374d419588a4632f3f557e76b4b70aebbca790"
TIKTOKEN_FILE="${TIKTOKEN_CACHE_DIR}/${TIKTOKEN_HASH}"

if [ ! -f "${TIKTOKEN_FILE}" ]; then
  echo "尚未找到 tiktoken vocab：${TIKTOKEN_FILE}"
  echo "嘗試下載 o200k_base.tiktoken..."

  if command -v curl >/dev/null 2>&1; then
    curl -L \
      "https://openaipublic.blob.core.windows.net/encodings/o200k_base.tiktoken" \
      -o "${TIKTOKEN_FILE}" || true
  elif command -v wget >/dev/null 2>&1; then
    wget \
      "https://openaipublic.blob.core.windows.net/encodings/o200k_base.tiktoken" \
      -O "${TIKTOKEN_FILE}" || true
  else
    echo "找不到 curl / wget，略過 tiktoken vocab 下載。"
  fi

  if [ ! -f "${TIKTOKEN_FILE}" ]; then
    echo "警告：tiktoken vocab 尚未準備好。"
    echo "如果啟動時出現 HarmonyError / tokenizer download error，請手動下載 o200k_base.tiktoken。"
  fi
else
  echo "tiktoken vocab 已存在：${TIKTOKEN_FILE}"
fi

# -------------------------------
# 若 container 已存在，先刪除
# -------------------------------

if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  echo "移除既有 container：${CONTAINER_NAME}"
  docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true
fi

# -------------------------------
# 組合 Docker 環境變數
# -------------------------------

DOCKER_ENV_ARGS=(
  -e HF_HOME="/root/.cache/huggingface"
  -e HF_HUB_OFFLINE="1"
  -e TRANSFORMERS_OFFLINE="1"
  -e TIKTOKEN_RS_CACHE_DIR="/tiktoken_encodings"
  -e TIKTOKEN_ENCODINGS_BASE="/tiktoken_encodings"
)

if [ "${USE_DGX_SPARK_FIX}" = "1" ]; then
  DOCKER_ENV_ARGS+=(
    -e VLLM_MXFP4_BACKEND="marlin"
    -e VLLM_MARLIN_USE_ATOMIC_ADD="1"
    -e FLASHINFER_DISABLE_VERSION_CHECK="1"
  )
fi

# -------------------------------
# 組合 vLLM 參數
# -------------------------------

VLLM_ARGS=(
  vllm serve "${CONTAINER_MODEL_PATH}"
  --served-model-name "${SERVED_MODEL_NAME}"
  --host 0.0.0.0
  --port "${PORT}"
  --gpu-memory-utilization "${GPU_MEMORY_UTILIZATION}"
  --max-model-len "${MAX_MODEL_LEN}"
  --max-num-batched-tokens "${MAX_NUM_BATCHED_TOKENS}"
)

if [ "${ENABLE_TOOLS}" = "1" ]; then
  VLLM_ARGS+=(
    --enable-auto-tool-choice
    --tool-call-parser openai
  )
fi

# 不要加：
#   --enforce-eager
#   --reasoning-parser openai_gptoss
#
# DGX Spark 文件提到 --enforce-eager 會讓速度明顯下降；
# reasoning-parser 可能讓一般 client 讀到 content: null。:contentReference[oaicite:2]{index=2}

# -------------------------------
# 啟動 vLLM Server
# -------------------------------

echo "=========================================="
echo "啟動 vLLM Server..."
echo "API Base URL: http://localhost:${PORT}/v1"
echo "Model name: ${SERVED_MODEL_NAME}"
echo "Container: ${CONTAINER_NAME}"
echo "=========================================="

docker run --rm --name "${CONTAINER_NAME}" -it \
  --privileged \
  --gpus all \
  --network=host \
  --ipc=host \
  --shm-size=64g \
  "${DOCKER_ENV_ARGS[@]}" \
  -v "${HOST_HF_CACHE}:/root/.cache/huggingface" \
  -v "${TIKTOKEN_CACHE_DIR}:/tiktoken_encodings" \
  "${IMAGE_NAME}" \
  "${VLLM_ARGS[@]}"