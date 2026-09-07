**English** | [繁體中文](01-dual-node-networking.zh-TW.md)

# Debugging the two-node QSFP link on DGX Spark

Two DGX Sparks (Spark A, Spark B) cabled together over QSFP could not talk to
each other. This records the full path from the physical layer down to SSH
authentication.

## Environment

| Item | Spark A | Spark B |
|---|---|---|
| Hostname | `gx10-bc71` | `gx10-46f3` |
| High-speed NIC address | `169.254.203.69/16` | `169.254.215.60/16` |
| Interface | `enp1s0f1np1` | `enp1s0f1np1` |
| User | `lab0616` | `lab0616` |

The username is the same on both machines, which is a prerequisite for the
passwordless SSH set up later.

## Investigation

### 1. Physical link and NIC state

First confirm the QSFP cable is seated correctly and the system sees the RoCE NIC:

```bash
ibdev2netdev
```

Both machines reported `rocep1s0f1 port 1 ==> enp1s0f1np1 (Up)`, confirming the
physical layer was fine and settling on `enp1s0f1np1` as the interface every
piece of distributed communication would later be pinned to.

### 2. Address assignment

```bash
ip addr show enp1s0f1np1
```

**The problem showed up here**:

- Spark B had picked up the link-local address `169.254.215.60/16`
- Spark A's interface was `UP` but had **no `inet` entry at all** — the NIC was
  alive with no IPv4 address

That was the root cause: the network layer had never come up.

### 3. Fixing Spark A with Netplan link-local addressing

Create a Netplan configuration on Spark A:

```bash
sudo tee /etc/netplan/40-cx7.yaml > /dev/null <<EOF
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

Spark A came up with `169.254.203.69/16`, putting both machines on the same segment.

### 4. Bidirectional passwordless SSH

A Ray cluster needs passwordless connectivity between nodes. Neither machine had
generated a key yet:

```bash
# Run on each machine, accepting the defaults with no passphrase
ssh-keygen
```

This produces an `ed25519` key at `~/.ssh/id_ed25519.pub`.

Exchange the public keys:

```bash
# On Spark A
ssh-copy-id -i ~/.ssh/id_ed25519.pub lab0616@169.254.215.60

# On Spark B
ssh-copy-id -i ~/.ssh/id_ed25519.pub lab0616@169.254.203.69
```

### 5. Verify

```bash
# On Spark A
ssh 169.254.215.60 hostname   # -> gx10-46f3

# On Spark B
ssh 169.254.203.69 hostname   # -> gx10-bc71
```

## Conclusion

The link failed because **Spark A never had Netplan's link-local addressing
applied** — the interface was `UP` but had no IPv4 address, so the network layer
could not carry anything. Adding the network configuration and generating and
exchanging ed25519 keys restored two-node communication.

Next: [deploying vLLM for cross-node inference on this cluster](02-dual-node-vllm-deployment.md)
