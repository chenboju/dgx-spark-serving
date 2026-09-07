#!/usr/bin/env bash
#
# Verify that this node's container can reach the peer's container over the
# MPI SSH channel. Run this before 03-serve.sh — an mpirun that cannot reach
# the peer hangs with no useful error, which is a slow way to find out.
#
# Usage: ./check-mpi-ssh.sh <peer-qsfp-ip>

set -euo pipefail
source "$(dirname "$0")/config.env"

PEER_IP="${1:-}"
if [[ -z "$PEER_IP" ]]; then
    echo "usage: $0 <peer-qsfp-ip>" >&2
    exit 1
fi

echo "--- host -> peer host (port 22) ---"
ssh -o BatchMode=yes -o ConnectTimeout=5 "$PEER_IP" hostname \
    && echo "OK" || echo "FAILED: host-level SSH trust is not set up"

echo "--- container -> peer container (port ${MPI_SSH_PORT}) ---"
docker exec "$CONTAINER_NAME" \
    ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
        -p "$MPI_SSH_PORT" "root@${PEER_IP}" hostname \
    && echo "OK" || echo "FAILED: run 02-setup-mpi-ssh.sh on both nodes"

echo "--- interface ${NET_IFACE} ---"
ip -brief addr show "$NET_IFACE" || echo "FAILED: interface not found"
