#!/bin/bash
: "${VLLM_API_KEY:?請先 source .env（可參考 .env.example）}"
export VLLM_CONTAINER=$(docker ps --format '{{.Names}}' | grep -E 'node-')

docker exec -it $VLLM_CONTAINER /bin/bash -c "
  export HF_TOKEN='${HF_TOKEN}'
  export VLLM_USE_V1=0
  
  # 確保所有高速網卡變數都在這層環境中生效
  export GLOO_SOCKET_IFNAME=enp1s0f1np1
  export NCCL_SOCKET_IFNAME=enp1s0f1np1
  export TP_SOCKET_IFNAME=enp1s0f1np1
  
  vllm serve 'Qwen/Qwen3-30B-A3B-Thinking-2507' \
    --tensor-parallel-size 2 \
    --trust-remote-code \
    --dtype bfloat16 \
    --gpu-memory-utilization 0.7 \
    --max-model-len 16000 \
    --served-model-name llm_chat \
    --api-key ${VLLM_API_KEY} \
    --port 8888
"