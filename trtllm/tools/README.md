**English** | [繁體中文](README.zh-TW.md)

# tools/

| File | Purpose |
|---|---|
| `check-backends.py` | Report which backends are actually serving, not just listening |
| `start-openwebui.sh` | Chat frontend against a running `trtllm-serve` |

## check-backends.py

A listening port is not a working server. `trtllm-serve` binds its port well before
the model finishes loading, which takes several minutes for a 120B model — so a
plain port check tells you nothing useful during exactly the window when you want to
know what is happening.

This checks both, which makes **"still loading" distinguishable from "crashed"**.

```bash
./check-backends.py                 # check the default ports
./check-backends.py 8355 8356       # check specific trtllm-serve ports
```

Worth running before assuming a launch failed. On a 120B model across two nodes,
the gap between "port is open" and "model answers" is long enough to look like a
hang.

## start-openwebui.sh

```bash
./start-openwebui.sh [trtllm-port]
```

`trtllm-serve` exposes an OpenAI-compatible API, so no adapter is needed — pointing
`OPENAI_API_BASE_URL` at it is enough.
