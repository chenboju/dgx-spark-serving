#!/usr/bin/env bash
#
# Nemotron 3 Super 120B-A12B (NVFP4) on ONE DGX Spark.
#
# This is the single-node configuration — it fits, but only just, and leaves
# little room for batching. The two-node tensor-parallel version is in
# ../multi-node/serve-nemotron3-120b.sh.
#
# Hybrid Mamba-2 / attention architecture. Note that the multi-node config
# additionally disables KV block reuse, which is a correctness requirement for
# Mamba-2 rather than a tuning choice; see docs/tuning-notes.md.
#
# Usage: HF_TOKEN=hf_... ./serve-nemotron3-120b.sh [port]

source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

MODEL_HANDLE="nvidia/NVIDIA-Nemotron-3-Super-120B-A12B-NVFP4"
DOCKER_IMAGE="nvcr.io/nvidia/tensorrt-llm/release:1.2.0rc6"
CONTAINER="trtllm_nemotron3_120b"

MEM_FRACTION="0.8"
MAX_BATCH_SIZE="64"
EXTRA_YAML="disable_overlap_scheduler: true"

launch_server "$@"
