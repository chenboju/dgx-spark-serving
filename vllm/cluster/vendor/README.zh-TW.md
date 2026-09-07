[English](README.md) | **繁體中文**

# vendor/ — 第三方檔案

本目錄的內容**不是本專案作者撰寫的**，僅為讓 `cluster/` 下的腳本能直接執行而收錄。

| 檔案 | 來源 | 授權 |
|---|---|---|
| `run_cluster.sh` | [vLLM](https://github.com/vllm-project/vllm) `examples/online_serving/run_cluster.sh` | Apache-2.0 |

未對其內容做任何修改。

`start-head.sh` 與 `start-worker.sh` 都會呼叫它來拉起 Ray 容器：

```bash
bash "$SCRIPT_DIR/vendor/run_cluster.sh" "$VLLM_IMAGE" "$VLLM_HOST_IP" --head ~/.cache/huggingface [-e ...]
```

本人對其他第三方專案的**修改**收在 [upstream/](../../upstream/README.zh-TW.md)，與此處性質不同。
