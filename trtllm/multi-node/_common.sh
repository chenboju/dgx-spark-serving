#!/usr/bin/env bash
#
# Shared launch logic for the two-node serving scripts.
#
# Each per-model script declares only what is different, then calls
# `launch_multinode`. Run these on the HEAD NODE ONLY — mpirun starts the peer
# rank itself over SSH.
#
# Required variables:
#   MODEL_HANDLE     HuggingFace repo id, or a local snapshot path
#   CONFIG_YAML      full contents of extra-llm-api-config.yml
#   PORT             trtllm-serve --port
#
# Optional variables:
#   MAX_SEQ_LEN          trtllm-serve --max_seq_len
#   NCCL_TCP_FALLBACK    1 to force NCCL off RDMA/P2P and onto TCP
#   MAX_BATCH_SIZE       defaults to 1 (a memory ceiling, not a choice)

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/config.env"

launch_multinode() {
    local var
    for var in MODEL_HANDLE CONFIG_YAML PORT; do
        if [[ -z "${!var:-}" ]]; then
            echo "error: $var is not set by the calling script" >&2
            return 1
        fi
    done

    if [[ -z "${HF_TOKEN:-}" ]]; then
        echo "warning: HF_TOKEN is not set — only pre-cached models will load." >&2
    fi

    echo "=== 1. Publishing OpenMPI hostfile to the container ==="
    if [[ ! -f "$HOSTFILE" ]]; then
        echo "error: $HOSTFILE not found (see hostfile.example)" >&2
        return 1
    fi
    docker cp "$HOSTFILE" "$CONTAINER_NAME:/etc/openmpi-hostfile"

    echo "=== 2. Writing extra-llm-api-config.yml ==="
    docker exec -e CONFIG_YAML="$CONFIG_YAML" "$CONTAINER_NAME" \
        bash -c 'printf "%s\n" "$CONFIG_YAML" > /tmp/extra-llm-api-config.yml'

    echo "=== 3. Launching tp_size=2 server on port ${PORT} ==="

    # TRT_LLM_DISABLE_LOAD_WEIGHTS_IN_PARALLEL=1 is not optional here. Parallel
    # weight loading spikes host RAM, and on a unified-memory machine that RAM
    # is the same pool the model is loading into — it OOMs the node.
    local docker_env=(
      -e HF_TOKEN="${HF_TOKEN:-}"
      -e TRT_LLM_DISABLE_LOAD_WEIGHTS_IN_PARALLEL=1
    )
    # Passed twice on purpose: `-e` covers the local rank, `-x` propagates to
    # the rank mpirun spawns on the peer, which does not inherit this
    # container's environment.
    local mpi_env=(-x HF_TOKEN)

    if [[ "${NCCL_TCP_FALLBACK:-0}" == "1" ]]; then
        docker_env+=(-e NCCL_P2P_DISABLE=1 -e NCCL_IB_DISABLE=1)
        mpi_env+=(-x NCCL_P2P_DISABLE=1 -x NCCL_IB_DISABLE=1)
    fi

    local serve_args=(
      --tp_size 2
      --backend pytorch
      --max_batch_size "${MAX_BATCH_SIZE:-1}"
      --trust_remote_code
      --extra_llm_api_options /tmp/extra-llm-api-config.yml
      --port "$PORT"
    )
    [[ -n "${MAX_SEQ_LEN:-}" ]] && serve_args+=(--max_seq_len "$MAX_SEQ_LEN")

    docker exec "${docker_env[@]}" -it "$CONTAINER_NAME" \
      mpirun --mca plm_rsh_args "-p ${MPI_SSH_PORT}" "${mpi_env[@]}" \
        trtllm-llmapi-launch \
        trtllm-serve "$MODEL_HANDLE" "${serve_args[@]}"
}
