#!/bin/bash
#
# [未驗證] 此組態尚未在雙節點上成功啟動。
# FP8 權重曾下載並同步至 Spark B，後因記憶體不足放棄，權重已刪除。
# ==========================================
# 雙節點叢集：NVIDIA Nemotron-3-Super-120B-A12B-FP8
# NVFP4 版本的對照組（見 serve-nemotron-3-super-120b-nvfp4.sh）
#
# 與 NVFP4 版的差異：
#   - FP8 走 FlashInfer MoE backend，不是 Marlin
#   - 開 expert parallel，MoE 層的 expert 拆到兩個節點
#   - context 只開到 16K：FP8 權重較大，記憶體換給了 batch
# ==========================================
: "${HF_TOKEN:?請先 source .env（可參考 .env.example）}"

export VLLM_CONTAINER=$(docker ps --format '{{.Names}}' | grep -E 'node-')

docker exec -it $VLLM_CONTAINER /bin/bash -c "
  export HF_TOKEN='${HF_TOKEN}'
  export VLLM_USE_V1=0

  # 高速網卡 (RoCE/NCCL)
  export MN_IF_NAME=enp1s0f1np1
  export NCCL_SOCKET_IFNAME=\$MN_IF_NAME
  export GLOO_SOCKET_IFNAME=\$MN_IF_NAME
  export TP_SOCKET_IFNAME=\$MN_IF_NAME

  # Nemotron FP8 特有的效能優化
  export VLLM_FLASHINFER_MOE_BACKEND=latency
  export VLLM_USE_FLASHINFER_MOE_FP8=1

  vllm serve 'nvidia/NVIDIA-Nemotron-3-Super-120B-A12B-FP8' \
    --tensor-parallel-size 2 \
    --enable-expert-parallel \
    --trust-remote-code \
    --dtype bfloat16 \
    --quantization fp8 \
    --kv-cache-dtype fp8 \
    --max-model-len 16000 \
    --gpu-memory-utilization 0.9 \
    --served-model-name nemotron_120b \
    --max-cudagraph-capture-size 32 \
    --port 8888
"
