# 取得目前容器名稱
: "${VLLM_API_KEY:?請先 source .env（可參考 .env.example）}"
export VLLM_CONTAINER=$(docker ps --format '{{.Names}}' | grep -E 'node-')

# 直接「進入房間」敲門
docker exec -it $VLLM_CONTAINER curl http://localhost:8888/v1/models \
  -H "Authorization: Bearer ${VLLM_API_KEY}"