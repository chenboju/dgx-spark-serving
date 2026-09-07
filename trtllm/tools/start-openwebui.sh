#!/usr/bin/env bash
#
# Open WebUI as a chat frontend for a running trtllm-serve instance.
# trtllm-serve exposes an OpenAI-compatible API, so no adapter is needed —
# pointing OPENAI_API_BASE_URL at it is enough.
#
# Usage: ./start-openwebui.sh [trtllm-port]

set -euo pipefail

TRTLLM_PORT="${1:-8355}"

echo "=== Starting Open WebUI against trtllm-serve on port ${TRTLLM_PORT} ==="

docker run -d \
  --name open-webui \
  --network host \
  --restart always \
  -e OPENAI_API_BASE_URL="http://localhost:${TRTLLM_PORT}/v1" \
  -v open-webui:/app/backend/data \
  ghcr.io/open-webui/open-webui:main

echo "Open WebUI available at http://localhost:8080"
