**English** | [繁體中文](README.zh-TW.md)

# qwen/ — Qwen family

| Script | Model | Notes |
|---|---|---|
| `qwen3-30b-a3b-thinking.sh` | `Qwen/Qwen3-30B-A3B-Thinking-2507` | MoE, 3B active parameters, reasoning model |
| `qwq-32b.sh` | `Qwen/QwQ-32B` | dense 32B, reasoning model |

## Relationship to the two-node version

The cluster version of `qwen3-30b-a3b-thinking.sh` is at
[cluster/serve-qwen3-30b-a3b.sh](../../cluster/serve-qwen3-30b-a3b.sh) — the
**first two-node configuration that worked** in this project.

How single-node and two-node differ:

| | Single node | Two nodes |
|---|---|---|
| TP size | 1 | 2 |
| Interface environment variables | not needed | NCCL / GLOO / TP all three required |
| How it starts | `docker run` | `docker exec` into the Ray container |

## Note

Thinking models emit reasoning content, so the client has to handle the
`reasoning_content` field, or turn it off in the request.
