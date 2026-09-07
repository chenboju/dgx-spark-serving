**English** | [繁體中文](multinode-networking.zh-TW.md)

# Bringing up the two-node QSFP link

Two DGX Spark units were cabled together back-to-back over QSFP so they could
run tensor-parallel inference as a single logical device. The physical link came
up, but MPI jobs could not reach the peer. This is what was actually wrong and
how it was found.

Throughout: **node A** and **node B**, interface `enp1s0f1np1` on both.

## 1. Confirm the link exists at all

```bash
ibdev2netdev
```

Both nodes reported:

```
rocep1s0f1 port 1 ==> enp1s0f1np1 (Up)
```

So the cable and the RoCE-capable port were fine, and `enp1s0f1np1` is the
interface every later step needs to be pinned to. Each Spark exposes two ports
(`enp1s0f0np0`, `enp1s0f1np1`); only the cabled one shows `Up`.

## 2. Check addressing

```bash
ip addr show enp1s0f1np1
```

This is where it broke:

| Node | State | IPv4 |
|------|-------|------|
| B    | `UP`  | `169.254.x.x/16` (auto-assigned) |
| A    | `UP`  | **none** — no `inet` line at all |

An interface can be `UP` at the link layer and still have no L3 address. Node A
had carrier but no IP, so nothing above the link layer could work. `ip link`
alone would have shown "up" on both and hidden the fault — checking `ip addr`
rather than `ip link` is the difference between finding this in two minutes and
not finding it.

## 3. Fix addressing on node A

No DHCP server exists on a back-to-back cable, so the only thing that will
assign an address is IPv4 link-local (RFC 3927). Node B had negotiated one;
node A had no netplan config telling it to.

```bash
sudo tee /etc/netplan/40-cx7.yaml > /dev/null <<'EOF'
network:
  version: 2
  ethernets:
    enp1s0f0np0:
      link-local: [ ipv4 ]
    enp1s0f1np1:
      link-local: [ ipv4 ]
EOF

sudo chmod 600 /etc/netplan/40-cx7.yaml
sudo netplan apply
```

Both ports are declared so the config survives moving the cable to the other
port. `chmod 600` is required — netplan refuses to apply world-readable files.

Node A then came up with a `169.254.x.x/16` address, putting both nodes on the
same segment.

## 4. Passwordless SSH between hosts

MPI launches remote ranks over SSH, so it must be non-interactive. Neither node
had a keypair yet.

```bash
# On each node
ssh-keygen -t ed25519          # no passphrase — mpirun cannot answer a prompt

# On A
ssh-copy-id -i ~/.ssh/id_ed25519.pub <user>@<node-B-ip>
# On B
ssh-copy-id -i ~/.ssh/id_ed25519.pub <user>@<node-A-ip>
```

Trust has to be **bidirectional**. Either node may end up as the head node, and
the container setup in
[`02-setup-mpi-ssh.sh`](../multi-node/02-setup-mpi-ssh.sh) copies the same
`authorized_keys` into both containers — so that one file must already contain
both public keys.

The username must match on both machines. MPI's default rsh launcher connects
as the current user without qualifying it.

## 5. Verify

```bash
# From A
ssh <node-B-ip> hostname     # -> node B's hostname, no password prompt
# From B
ssh <node-A-ip> hostname     # -> node A's hostname, no password prompt
```

Both succeeded, and multi-node launches worked from that point.

## Root cause

Node A never had IPv4 link-local addressing configured, so it held carrier
without an address and the two nodes were never on the same L3 segment. Adding
the netplan config and generating/exchanging ed25519 keys resolved it.

## Known limitation

Link-local addresses are negotiated at boot and are **not guaranteed stable**
across reboots. The OpenMPI hostfile pins them literally, so a reboot can
silently break the cluster. Static addresses on the QSFP segment would fix this
properly; it has not been done yet.
