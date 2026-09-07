#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 確保變數已設定
export VLLM_IMAGE=nvcr.io/nvidia/vllm:26.02-py3
export VLLM_HOST_IP=169.254.203.69
export MN_IF_NAME=enp1s0f1np1

# 加入 -p 參數來映射埠號，並補齊高速網卡與 Ray 的環境變數
bash "$SCRIPT_DIR/vendor/run_cluster.sh" $VLLM_IMAGE $VLLM_HOST_IP --head ~/.cache/huggingface \
  -p 8888:8888 \
  -e VLLM_HOST_IP=$VLLM_HOST_IP \
  -e UCX_NET_DEVICES=$MN_IF_NAME \
  -e NCCL_SOCKET_IFNAME=$MN_IF_NAME \
  -e OMPI_MCA_btl_tcp_if_include=$MN_IF_NAME \
  -e GLOO_SOCKET_IFNAME=$MN_IF_NAME \
  -e TP_SOCKET_IFNAME=$MN_IF_NAME \
  -e RAY_memory_monitor_refresh_ms=0 \
  -e MASTER_ADDR=$VLLM_HOST_IP