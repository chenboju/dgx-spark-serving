#!/usr/bin/env bash
#
# Shared launch logic for the single-node serving scripts.
#
# Each per-model script declares only what is different about that model, then
# calls `launch_server`. The docker invocation itself lives here so that fixing
# it does not mean editing five files and missing one.
#
# Required variables:
#   MODEL_HANDLE     HuggingFace repo id
#   DOCKER_IMAGE     TRT-LLM release container
#   CONTAINER        docker container name
#   MEM_FRACTION     kv_cache_config.free_gpu_memory_fraction
#   MAX_BATCH_SIZE   trtllm-serve --max_batch_size
#
# Optional variables:
#   EXTRA_YAML       extra lines appended to extra-llm-api-config.yml
#   PRE_CMD          shell command run inside the container before serving
#   DEFAULT_PORT     defaults to 8355

set -euo pipefail

launch_server() {
    local port="${1:-${DEFAULT_PORT:-8355}}"

    local var
    for var in MODEL_HANDLE DOCKER_IMAGE CONTAINER MEM_FRACTION MAX_BATCH_SIZE; do
        if [[ -z "${!var:-}" ]]; then
            echo "error: $var is not set by the calling script" >&2
            return 1
        fi
    done

    # Gated repos need a token to download; already-cached models do not.
    if [[ -z "${HF_TOKEN:-}" ]]; then
        echo "warning: HF_TOKEN is not set — gated model downloads will fail." >&2
    fi

    local config_yaml
    read -r -d '' config_yaml <<YAML || true
print_iter_log: false
kv_cache_config:
  dtype: "auto"
  free_gpu_memory_fraction: ${MEM_FRACTION}
cuda_graph_config:
  enable_padding: true
${EXTRA_YAML:-}
YAML

    echo "=== Serving ${MODEL_HANDLE} on port ${port} ==="

    # The config is passed through the environment and written inside the
    # container. Generating it with a heredoc nested in the `bash -c` string
    # works but is fragile to quote, which is how the original scripts did it.
    docker run --name "$CONTAINER" --rm -it \
      --gpus all \
      --ipc host \
      --network host \
      -e HF_TOKEN="${HF_TOKEN:-}" \
      -e MODEL_HANDLE="$MODEL_HANDLE" \
      -e EXTRA_LLM_API_CONFIG="$config_yaml" \
      -e PRE_CMD="${PRE_CMD:-:}" \
      -e MAX_BATCH_SIZE="$MAX_BATCH_SIZE" \
      -e SERVE_PORT="$port" \
      -v "$HOME/.cache/huggingface/:/root/.cache/huggingface/" \
      "$DOCKER_IMAGE" \
      bash -c '
        set -euo pipefail
        eval "$PRE_CMD"
        hf download "$MODEL_HANDLE"
        printf "%s\n" "$EXTRA_LLM_API_CONFIG" > /tmp/extra-llm-api-config.yml
        trtllm-serve "$MODEL_HANDLE" \
          --max_batch_size "$MAX_BATCH_SIZE" \
          --trust_remote_code \
          --port "$SERVE_PORT" \
          --extra_llm_api_options /tmp/extra-llm-api-config.yml
      '
}
