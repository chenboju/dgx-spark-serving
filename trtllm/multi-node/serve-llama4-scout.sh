#!/usr/bin/env bash
#
# Llama 4 Scout 17B-16E Instruct (NVFP4) across two DGX Sparks, tp_size=2.
#
# Needs NCCL_TCP_FALLBACK: without it, collective init hangs. Forcing NCCL onto
# TCP over the QSFP link makes it start but gives up the RDMA path, so this is
# a workaround with an unmeasured cost — see docs/tuning-notes.md.
#
# max_seq_len is capped at 8192. Combined with max_batch_size 1, this is what
# fit alongside the weights and NCCL buffers.
#
# Run on the HEAD NODE only, after 01-init-container.sh and 02-setup-mpi-ssh.sh
# have run on both nodes.
#
# Usage: HF_TOKEN=hf_... ./serve-llama4-scout.sh

source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

MODEL_HANDLE="nvidia/Llama-4-Scout-17B-16E-Instruct-NVFP4"
PORT="8355"
MAX_SEQ_LEN="8192"
NCCL_TCP_FALLBACK=1

read -r -d '' CONFIG_YAML <<'YAML' || true
print_iter_log: false
kv_cache_config:
  dtype: "auto"
  free_gpu_memory_fraction: 0.8
cuda_graph_config:
  enable_padding: true
YAML

launch_multinode
