#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export MN_IF_NAME=enp1s0f1np1
export VLLM_HOST_IP=169.254.215.60
export HEAD_NODE_IP=169.254.203.69
export VLLM_IMAGE=nvcr.io/nvidia/vllm:26.02-py3

bash "$SCRIPT_DIR/vendor/run_cluster.sh" $VLLM_IMAGE $HEAD_NODE_IP --worker ~/.cache/huggingface \
  -e VLLM_HOST_IP=$VLLM_HOST_IP \
  -e UCX_NET_DEVICES=$MN_IF_NAME \
  -e NCCL_SOCKET_IFNAME=$MN_IF_NAME \
  -e GLOO_SOCKET_IFNAME=$MN_IF_NAME \
  -e TP_SOCKET_IFNAME=$MN_IF_NAME \
  -e MASTER_ADDR=$HEAD_NODE_IP