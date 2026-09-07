**English** | [繁體中文](README.zh-TW.md)

# tools/ — helper utilities

| File | Purpose |
|---|---|
| `hf-cache-report.py` | Reports actual disk usage per model in the HF cache |
| `hf-download.py` | Downloads models with `hf_transfer` acceleration |

## hf-cache-report.py

On a machine with 128 GB of unified memory that has to hold several 120B-class
models, working out what is eating the disk is a daily need.

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

It counts real files and skips symlinks, so the figure is true usage rather than
the HF cache's apparent size.

The cache path defaults to `~/.cache/huggingface/hub` and can be overridden with
`HF_HOME_HUB`.

## hf-download.py

```bash
export HF_TOKEN=...
python3 hf-download.py
```

Sets `HF_HUB_ENABLE_HF_TRANSFER=1` with `max_workers=8`, which is noticeably
faster for 100 GB-class models. Supports resuming interrupted downloads.

The model id is currently hard-coded — change the `model_id` variable to download
something else.
