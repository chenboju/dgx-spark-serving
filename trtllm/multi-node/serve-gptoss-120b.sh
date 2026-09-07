#!/usr/bin/env bash
#
# GPT-OSS 120B across two DGX Sparks, tp_size=2.
#
# The only model here not run from an NVFP4 conversion — it uses the stock
# openai/gpt-oss-120b weights.
#
# Needs NCCL_TCP_FALLBACK, same as Llama 4 Scout. The 0.7 memory fraction was
# carried over from a vLLM --gpu-memory-utilization setting for this model and
# then left alone once it worked; it was never tuned against TRT-LLM.
#
# If hub resolution is slow or the repo id keeps re-resolving, point at a local
# snapshot instead:
#
#   MODEL_HANDLE=/root/.cache/huggingface/hub/models--openai--gpt-oss-120b/snapshots/<sha> \
#     ./serve-gptoss-120b.sh
#
# Run on the HEAD NODE only, after 01-init-container.sh and 02-setup-mpi-ssh.sh
# have run on both nodes.
#
# Usage: HF_TOKEN=hf_... ./serve-gptoss-120b.sh

source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

MODEL_HANDLE="${MODEL_HANDLE:-openai/gpt-oss-120b}"
PORT="8887"
MAX_SEQ_LEN="32000"
NCCL_TCP_FALLBACK=1

read -r -d '' CONFIG_YAML <<'YAML' || true
print_iter_log: false
kv_cache_config:
  dtype: "auto"
  free_gpu_memory_fraction: 0.7
cuda_graph_config:
  enable_padding: true
YAML

launch_multinode
