#!/usr/bin/env bash
#
# GLM-4.7 Flash (NVFP4) on one DGX Spark.
#
# The 1.2.0rc6 container ships a `transformers` predating this model's config
# format, so loading fails on an unrecognised architecture. Upgrading in-place
# at startup is a workaround; baking a known-good version into a derived image
# would be the proper fix.
#
# Usage: HF_TOKEN=hf_... ./serve-glm47-flash.sh [port]

source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

MODEL_HANDLE="GadflyII/GLM-4.7-Flash-NVFP4"
DOCKER_IMAGE="nvcr.io/nvidia/tensorrt-llm/release:1.2.0rc6"
CONTAINER="trtllm_glm47_flash"

MEM_FRACTION="0.9"
MAX_BATCH_SIZE="64"
PRE_CMD="pip install --upgrade transformers"

launch_server "$@"
