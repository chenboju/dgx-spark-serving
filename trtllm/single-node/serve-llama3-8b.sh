#!/usr/bin/env bash
#
# Llama 3.1 8B Instruct (NVFP4) on one DGX Spark.
#
# The smallest model here and the one used to validate the toolchain before
# moving on to the MoE models. Dense 8B weights leave plenty of room, so the KV
# cache gets the most aggressive memory fraction of any config in this repo.
#
# Usage: HF_TOKEN=hf_... ./serve-llama3-8b.sh [port]

source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

MODEL_HANDLE="nvidia/Llama-3.1-8B-Instruct-NVFP4"
DOCKER_IMAGE="nvcr.io/nvidia/tensorrt-llm/release:1.2.0rc6"
CONTAINER="trtllm_llama3_8b"

MEM_FRACTION="0.9"
MAX_BATCH_SIZE="64"

launch_server "$@"
