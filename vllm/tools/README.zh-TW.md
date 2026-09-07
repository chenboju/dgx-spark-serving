[English](README.md) | **繁體中文**

# tools/ — 輔助工具

| 檔案 | 用途 |
|---|---|
| `hf-cache-report.py` | 列出 HF cache 內各模型的實際佔用空間 |
| `hf-download.py` | 以 `hf_transfer` 加速下載模型 |

## hf-cache-report.py

在只有 128GB unified memory、又要放好幾個 120B 級模型的機器上，
搞清楚硬碟被誰吃掉是日常需求。

```bash
python3 hf-cache-report.py
```

```
模型名稱 (Model Name)                         | 佔用空間 (Size)
-----------------------------------------------------------------
openai/gpt-oss-120b                           |  59.03 GB
nvidia/Gemma-4-26B-A4B-NVFP4                  |  14.21 GB
-----------------------------------------------------------------
總計 (Total)                                  |  73.24 GB
```

只計算實體檔案、跳過 symlink，所以算出來的是真實佔用而非 HF cache 的表面大小。

快取路徑預設 `~/.cache/huggingface/hub`，可用 `HF_HOME_HUB` 覆蓋。

## hf-download.py

```bash
export HF_TOKEN=...
python3 hf-download.py
```

啟用 `HF_HUB_ENABLE_HF_TRANSFER=1` 搭配 `max_workers=8`，
下載 100GB 級模型時比預設快不少。支援斷點續傳。

目前 model id 寫在檔案裡，要改下載對象得編輯 `model_id` 變數。
