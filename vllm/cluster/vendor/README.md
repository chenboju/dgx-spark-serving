**English** | [繁體中文](README.zh-TW.md)

# vendor/ — third-party files

Nothing in this directory **was written by the author of this project**. It is
included only so the scripts under `cluster/` can run as-is.

| File | Source | Licence |
|---|---|---|
| `run_cluster.sh` | [vLLM](https://github.com/vllm-project/vllm) `examples/online_serving/run_cluster.sh` | Apache-2.0 |

The contents are unmodified.

Both `start-head.sh` and `start-worker.sh` call it to bring up the Ray container:

```bash
bash "$SCRIPT_DIR/vendor/run_cluster.sh" "$VLLM_IMAGE" "$VLLM_HOST_IP" --head ~/.cache/huggingface [-e ...]
```

My own **modifications** to other third-party projects are kept in
[upstream/](../../upstream/), which is a different thing from this directory.
