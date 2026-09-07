**English** | [繁體中文](02-dual-node-vllm-deployment.zh-TW.md)

# Deploying vLLM across two DGX Sparks

Building a distributed Ray cluster over QSFP on two DGX Sparks, and running
`Qwen3-30B-A3B-Thinking-2507` with cross-node tensor parallelism (TP=2) under vLLM.

Prerequisite: [debugging the two-node QSFP link](01-dual-node-networking.md).

## Environment

- **Head node (Spark A)**: `gx10-bc71`, `169.254.203.69`
- **Worker node (Spark B)**: `gx10-46f3`, `169.254.215.60`
- **High-speed interface**: `enp1s0f1np1`
- **Docker image**: `nvcr.io/nvidia/vllm:26.02-py3`

## The key point: all the network variables have to be set together

Cross-node communication goes through several different transport layers, each
reading its own environment variable. Set only one or two and vLLM silently falls
back to a slow interface — or hangs during initialisation:

| Variable | Purpose |
|---|---|
| `NCCL_SOCKET_IFNAME` | NCCL collectives (the actual tensor traffic) |
| `GLOO_SOCKET_IFNAME` | PyTorch distributed control plane |
| `TP_SOCKET_IFNAME` | vLLM tensor-parallel socket binding |
| `UCX_NET_DEVICES` | UCX transport device selection |
| `OMPI_MCA_btl_tcp_if_include` | OpenMPI TCP BTL interface allow-list |

Separately, `RAY_memory_monitor_refresh_ms=0` disables Ray's memory monitor —
memory use spikes briefly while the model loads, and the monitor misreads that
spike and kills the worker process outright.

## Startup

### Step 1: head node (Spark A)

See [`cluster/start-head.sh`](../cluster/start-head.sh):

```bash
export VLLM_IMAGE=nvcr.io/nvidia/vllm:26.02-py3
export VLLM_HOST_IP=169.254.203.69
export MN_IF_NAME=enp1s0f1np1

bash run_cluster.sh $VLLM_IMAGE $VLLM_HOST_IP --head ~/.cache/huggingface \
  -p 8888:8888 \
  -e VLLM_HOST_IP=$VLLM_HOST_IP \
  -e UCX_NET_DEVICES=$MN_IF_NAME \
  -e NCCL_SOCKET_IFNAME=$MN_IF_NAME \
  -e OMPI_MCA_btl_tcp_if_include=$MN_IF_NAME \
  -e GLOO_SOCKET_IFNAME=$MN_IF_NAME \
  -e TP_SOCKET_IFNAME=$MN_IF_NAME \
  -e RAY_memory_monitor_refresh_ms=0 \
  -e MASTER_ADDR=$VLLM_HOST_IP
```

### Step 2: worker node (Spark B)

See [`cluster/start-worker.sh`](../cluster/start-worker.sh). The variables match
the head node; the difference is that `VLLM_HOST_IP` points at itself and
`MASTER_ADDR` points at the head.

### Step 3: confirm cluster state

```bash
export VLLM_CONTAINER=$(docker ps --format '{{.Names}}' | grep -E 'node-')
docker exec $VLLM_CONTAINER ray status
# expect 2 Active nodes
```

### Step 4: start the inference server

See [`cluster/serve-qwen3-30b-a3b.sh`](../cluster/serve-qwen3-30b-a3b.sh). Note
that `--max-model-len` has to be capped, or startup runs out of memory.

### Step 5: verify

```bash
curl http://localhost:8888/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${VLLM_API_KEY}" \
  -d '{
    "model": "llm_chat",
    "messages": [{"role": "user", "content": "test"}],
    "max_tokens": 100
  }'
```

## Troubleshooting log

### `No such container: pkill`

`docker exec -it $VLLM_CONTAINER pkill -9 python` failed.

**Cause**: no container starting with `node-` was running at the time, so
`$VLLM_CONTAINER` was an empty string and docker parsed `pkill` as the container
name.

**Fix**: `echo $VLLM_CONTAINER` before running anything to confirm the variable
actually resolved.

### Worker node: `Failed to resolve 'huggingface.co'`

Spark B raised a DNS resolution failure (`[Errno -3]`) and could not download
model weights.

**Cause**: the worker node has no outside network access.

**Fix**: leave the network configuration alone and sync the HF cache Spark A had
already downloaded across the QSFP link instead.

### `Permission denied` while syncing the cache

**Cause**: Spark B's `~/.cache/huggingface` had been created earlier by the
Docker daemon, so it was owned by `root` and not writable by a normal user.

**Fix**:

```bash
# -t forces TTY allocation so sudo can read the password prompt remotely
ssh -t lab0616@169.254.215.60 "sudo chown -R lab0616:lab0616 ~/.cache/huggingface"

rsync -avP ~/.cache/huggingface/ lab0616@169.254.215.60:~/.cache/huggingface/
```

### `Errno 98 Address already in use`

A Python process from a previous start was never cleaned up.

```bash
docker exec -it $VLLM_CONTAINER pkill -9 python
```

Full cleanup when the whole cluster is wedged:

```bash
docker stop $(docker ps -a -q --filter "name=node-") && \
docker rm $(docker ps -a -q --filter "name=node-")
```

## Everyday operations

```bash
# Get the current vLLM container name
export VLLM_CONTAINER=$(docker ps --format '{{.Names}}' | grep -E 'node-')

# Shell into the container
docker exec -it $VLLM_CONTAINER /bin/bash

# Live logs (for catching startup errors)
docker logs -f $VLLM_CONTAINER

# GPU utilisation
watch -n 1 nvidia-smi

# Check InfiniBand / RoCE interface mapping
ibdev2netdev
```
