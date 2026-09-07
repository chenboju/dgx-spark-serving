#!/usr/bin/env bash
#
# Step 2 — bring up an sshd inside the container so mpirun can launch remote
# ranks. Run on BOTH nodes, after 01-init-container.sh.
#
# ---------------------------------------------------------------------------
# SECURITY NOTE — read before reusing this.
#
# This enables root login and disables strict host key checking inside the
# container. That is acceptable *only* because of how this cluster is wired:
# the two nodes are connected back-to-back by a single QSFP cable on an
# isolated link-local segment with no gateway and no other hosts, and the
# container is torn down with the job.
#
# On any shared or routable network this needs to become: a non-root MPI user,
# a pre-populated known_hosts, and sshd bound to the QSFP interface only.
# ---------------------------------------------------------------------------

set -euo pipefail
source "$(dirname "$0")/config.env"

echo "=== Configuring in-container SSH on port ${MPI_SSH_PORT} ==="

docker exec -u root "$CONTAINER_NAME" bash -c "
set -euo pipefail
apt-get update && apt-get install -y openssh-server
mkdir -p /run/sshd /root/.ssh
chmod 700 /root/.ssh

# The host's keypair is mounted read-only at /tmp/.ssh by 01-init-container.sh.
# authorized_keys must already contain BOTH nodes' public keys — that exchange
# happens on the host side, see docs/multinode-networking.md.
cp /tmp/.ssh/id_ed25519     /root/.ssh/id_ed25519
cp /tmp/.ssh/authorized_keys /root/.ssh/authorized_keys
chmod 600 /root/.ssh/id_ed25519 /root/.ssh/authorized_keys

echo 'Port ${MPI_SSH_PORT}'      >> /etc/ssh/sshd_config
echo 'PermitRootLogin yes'       >> /etc/ssh/sshd_config
echo 'PubkeyAuthentication yes'  >> /etc/ssh/sshd_config
echo 'StrictHostKeyChecking no'  >> /etc/ssh/ssh_config

pkill sshd || true
/usr/sbin/sshd
"

echo "SSH ready. Verify with: ./check-mpi-ssh.sh <peer-ip>"
