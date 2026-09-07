#!/bin/bash
#
# [未驗證] 此組態尚未在雙節點上成功啟動，保留作為後續除錯的起點。
# 實際嘗試是透過第三方 spark-vllm-docker 的 run-recipe（7 次），本腳本為手寫等價版本。
# ==========================================
# 雙節點叢集：NVIDIA Nemotron-3-Super-120B-A12B-NVFP4
# TP=2 跨兩台 DGX Spark，走 QSFP 高速網卡
#
# 重點：NVFP4 在 GB10 上改用 Marlin GEMM kernel，
#       搭配 fp8 KV cache 才塞得下 256K context。
# ==========================================
: "${HF_TOKEN:?請先 source .env（可參考 .env.example）}"

export VLLM_CONTAINER=$(docker ps --format '{{.Names}}' | grep -E 'node-')

docker exec -it $VLLM_CONTAINER /bin/bash -c "
  export HF_TOKEN='${HF_TOKEN}'
  export VLLM_USE_V1=0

  # 高速網卡：三個變數都要在容器這層生效，缺一個就會退回慢速介面
  export GLOO_SOCKET_IFNAME=enp1s0f1np1
  export NCCL_SOCKET_IFNAME=enp1s0f1np1
  export TP_SOCKET_IFNAME=enp1s0f1np1

  # NVFP4 走 Marlin 核心的效能優化
  export VLLM_NVFP4_GEMM_BACKEND='marlin'
  export VLLM_TEST_FORCE_FP8_MARLIN='1'
  export VLLM_MARLIN_USE_ATOMIC_ADD='1'

  # Nemotron 專屬 reasoning parser，模型正常運作的必要條件
  wget -qO super_v3_reasoning_parser.py \
    https://huggingface.co/nvidia/NVIDIA-Nemotron-3-Super-120B-A12B-NVFP4/raw/main/super_v3_reasoning_parser.py

  vllm serve 'nvidia/NVIDIA-Nemotron-3-Super-120B-A12B-NVFP4' \
    --tensor-parallel-size 2 \
    --trust-remote-code \
    --kv-cache-dtype fp8 \
    --gpu-memory-utilization 0.7 \
    --max-model-len 262144 \
    --max-num-seqs 10 \
    --enable-prefix-caching \
    --enable-auto-tool-choice \
    --tool-call-parser qwen3_coder \
    --reasoning-parser-plugin super_v3_reasoning_parser.py \
    --reasoning-parser super_v3 \
    --port 8888
"
