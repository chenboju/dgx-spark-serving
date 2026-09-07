#!/bin/bash
# ==========================================
# 雙節點叢集：openai/gpt-oss-120b
# TP=2 跨兩台 DGX Spark，走 QSFP 高速網卡
#
# 120B 級模型能塞進雙節點的關鍵：
#   - MXFP4 原生量化權重（不展開成 bf16）
#   - --kv-cache-dtype fp8，KV cache 減半才撐得住 32K context
#
# 用 8889 port，與 serve-qwen3-30b-a3b.sh 的 8888 錯開，可並存。
# ==========================================
: "${HF_TOKEN:?請先 source .env（可參考 .env.example）}"
: "${VLLM_API_KEY:?請先 source .env（可參考 .env.example）}"

# 取得目前運行中的 Ray/vLLM 容器名稱
export VLLM_CONTAINER=$(docker ps --format '{{.Names}}' | grep -E 'node-')

docker exec -it $VLLM_CONTAINER /bin/bash -c "
  export HF_TOKEN='${HF_TOKEN}'
  export VLLM_USE_V1=0
  export GLOO_SOCKET_IFNAME=enp1s0f1np1
  export NCCL_SOCKET_IFNAME=enp1s0f1np1
  export TP_SOCKET_IFNAME=enp1s0f1np1
  
  vllm serve 'openai/gpt-oss-120b' \
    --tensor-parallel-size 2 \
    --trust-remote-code \
    --dtype bfloat16 \
    --kv-cache-dtype fp8 \
    --gpu-memory-utilization 0.7 \
    --max-model-len 32000 \
    --served-model-name gptoss_chat \
    --api-key ${VLLM_API_KEY} \
    --port 8889
"