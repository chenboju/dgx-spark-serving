#!/usr/bin/env bash
#
# Llama 4 Scout 17B-16E Instruct (NVFP4) on one DGX Spark.
#
# 16-expert MoE. `disable_overlap_scheduler` was added while chasing
# instability and kept once things were stable — it has not been isolated as
# the actual fix, see docs/tuning-notes.md.
#
# Usage: HF_TOKEN=hf_... ./serve-llama4-scout.sh [port]

source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

MODEL_HANDLE="nvidia/Llama-4-Scout-17B-16E-Instruct-NVFP4"
DOCKER_IMAGE="nvcr.io/nvidia/tensorrt-llm/release:1.2.0rc6"
CONTAINER="trtllm_llama4_scout"

MEM_FRACTION="0.9"
MAX_BATCH_SIZE="64"
EXTRA_YAML="disable_overlap_scheduler: true"

launch_server "$@"
