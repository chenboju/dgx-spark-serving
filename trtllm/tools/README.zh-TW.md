[English](README.md) | **繁體中文**

# tools/

| 檔案 | 用途 |
|---|---|
| `check-backends.py` | 回報哪些 backend 真的在服務，而不只是「port 開著」 |
| `start-openwebui.sh` | 對接執行中 `trtllm-serve` 的聊天前端 |

## check-backends.py

port 有在聽不等於伺服器可用。`trtllm-serve` 會在模型載入完成**之前很久**
就綁定 port，而 120B 模型要載入好幾分鐘——所以單純檢查 port，
在你最想知道狀況的那段時間裡，恰恰什麼都告訴不了你。

這支兩者都檢查，因此能**區分「仍在載入」與「已崩潰」**。

```bash
./check-backends.py                 # 檢查預設 port
./check-backends.py 8355 8356       # 檢查指定的 trtllm-serve port
```

在斷定啟動失敗之前值得先跑一次。120B 模型跨兩個節點時，
「port 開了」到「模型會回應」之間的間隔，長到足以看起來像卡死。

## start-openwebui.sh

```bash
./start-openwebui.sh [trtllm-port]
```

`trtllm-serve` 提供 OpenAI 相容 API，因此不需要任何轉接層——
把 `OPENAI_API_BASE_URL` 指過去就可以。
