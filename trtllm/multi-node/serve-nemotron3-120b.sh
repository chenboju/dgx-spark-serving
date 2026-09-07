#!/usr/bin/env bash
#
# Nemotron 3 Super 120B-A12B (NVFP4) across two DGX Sparks, tp_size=2.
#
# Two settings here are correctness requirements from the model card, not
# tuning knobs:
#
#   enable_block_reuse: false
#       This is a hybrid Mamba-2 / attention model. KV block reuse assumes a
#       cached block is a pure function of the tokens that produced it, which
#       recurrent SSM state does not satisfy.
#
#   moe_config.backend: CUTLASS
#       Required for the MoE layers on this architecture.
#
# The memory fraction is 0.4, half the single-node value, because each rank now
# also holds NCCL buffers and the MPI runtime — and on unified memory those come
# out of the same pool as the KV cache.
#
# This is the only one of the three multi-node models that runs without the
# NCCL TCP fallback, which is why that workaround is still unexplained.
#
# Run on the HEAD NODE only, after 01-init-container.sh and 02-setup-mpi-ssh.sh
# have run on both nodes.
#
# Usage: HF_TOKEN=hf_... ./serve-nemotron3-120b.sh

source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

MODEL_HANDLE="nvidia/NVIDIA-Nemotron-3-Super-120B-A12B-NVFP4"
PORT="8356"

read -r -d '' CONFIG_YAML <<'YAML' || true
kv_cache_config:
  enable_block_reuse: false
  free_gpu_memory_fraction: 0.4
cuda_graph_config:
  max_batch_size: 32
  enable_padding: true
moe_config:
  backend: CUTLASS
YAML

launch_multinode
