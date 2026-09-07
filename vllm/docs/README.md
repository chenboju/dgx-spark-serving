**English** | [繁體中文](README.zh-TW.md)

# docs/ — build and debugging notes

The full path from two DGX Sparks out of the box to cross-node inference running.
Read in order.

| Document | Contents |
|---|---|
| [01-dual-node-networking.md](01-dual-node-networking.md) | QSFP physical link debugging: `ibdev2netdev` → Netplan link-local → SSH key exchange |
| [02-dual-node-vllm-deployment.md](02-dual-node-vllm-deployment.md) | vLLM across machines: aligning network variables, Ray's memory monitor killing workers, syncing the cache to a worker with no outside network |

## What these two actually record

They are not operating manuals — they are **troubleshooting records**. Every step
corresponds to something that actually got stuck:

- The interface reported `UP` but had no IPv4 address, because the Netplan
  link-local configuration had not been applied
- Five network environment variables (NCCL / GLOO / TP / UCX / OpenMPI) each
  govern a different part of the transport layer; setting only one or two makes
  it silently fall back to a slow interface
- Ray's memory monitor misreads the load-time spike and kills the worker process
- The worker node has no outside network, so the HF cache is synced over the QSFP
  link with rsync instead
- That sync fails with `Permission denied`, because the target directory was
  created as root by the Docker daemon

The runnable scripts these correspond to are in [cluster/](../cluster/).
