import os
# 強制啟用加速套件
os.environ["HF_HUB_ENABLE_HF_TRANSFER"] = "1"

from huggingface_hub import snapshot_download

# 設定你的 Token (建議設定，避免限速)
token = os.environ["HF_TOKEN"]

model_id = "Qwen/Qwen3.6-27B"

print(f"正在下載模型至預設快取路徑...")

# 不設定 local_dir，它會自動下載到 C:\Users\<user>\.cache\huggingface\hub
snapshot_download(
    repo_id=model_id,
    token=token,
    endpoint=None, 
    resume_download=True, # 支援斷點續傳
    max_workers=8         # 增加執行緒 (搭配 hf_transfer 效果極佳)
)

print("下載完成！檔案已妥善存放在 .cache 目錄中。")