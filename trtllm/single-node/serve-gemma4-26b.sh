#!/usr/bin/env bash
#
# Gemma 4 26B-A4B (NVFP4) on one DGX Spark.
#
# Needs a newer container than the other single-node models — 1.3.0rc13 is the
# first release tag this model loaded on.
#
# The memory fraction is 0.7 rather than the 0.9 used for the smaller models:
# at 0.9 the KV cache allocation left too little for activations and the load
# failed. See docs/tuning-notes.md.
#
# Usage: HF_TOKEN=hf_... ./serve-gemma4-26b.sh [port]

source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

MODEL_HANDLE="nvidia/Gemma-4-26B-A4B-NVFP4"
DOCKER_IMAGE="nvcr.io/nvidia/tensorrt-llm/release:1.3.0rc13"
CONTAINER="trtllm_gemma4_26b"

MEM_FRACTION="0.7"
MAX_BATCH_SIZE="64"
DEFAULT_PORT="8356"

launch_server "$@"
