#!/usr/bin/env bash
#
# Step 1 — start the long-lived TRT-LLM container on BOTH nodes.
#
# The container just sleeps; it is a persistent execution environment that
# steps 2 and 3 exec into. Starting the server directly with `docker run` does
# not work for multi-node: mpirun needs to reach a running sshd on the peer
# before the model is loaded.

set -euo pipefail
source "$(dirname "$0")/config.env"

# Remove any container left behind by a previous run. A crashed multi-node job
# can leave one alive, and `docker run --name` then fails on the name clash.
docker stop "$CONTAINER_NAME" 2>/dev/null || true

echo "=== Starting ${TRTLLM_IMAGE} as ${CONTAINER_NAME} ==="

docker run -d --rm \
  --name "$CONTAINER_NAME" \
  --gpus '"device=all"' \
  --network host \
  --ulimit memlock=-1 \
  --ulimit stack=67108864 \
  --device /dev/infiniband:/dev/infiniband \
  -e UCX_NET_DEVICES="$NET_IFACE" \
  -e NCCL_SOCKET_IFNAME="$NET_IFACE" \
  -e OMPI_MCA_btl_tcp_if_include="$NET_IFACE" \
  -e OMPI_MCA_orte_default_hostfile="/etc/openmpi-hostfile" \
  -e OMPI_MCA_rmaps_ppr_n_pernode="1" \
  -e OMPI_ALLOW_RUN_AS_ROOT="1" \
  -e OMPI_ALLOW_RUN_AS_ROOT_CONFIRM="1" \
  -v "$HOME/.cache/huggingface/:/root/.cache/huggingface/" \
  -v "$HOME/.ssh:/tmp/.ssh:ro" \
  "$TRTLLM_IMAGE" \
  sh -c "sleep infinity"

echo "Container started. Run 02-setup-mpi-ssh.sh next (on both nodes)."
