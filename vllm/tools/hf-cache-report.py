import os
from pathlib import Path

def get_model_sizes(cache_path):
    cache_dir = Path(cache_path)
    
    if not cache_dir.exists():
        print(f"找不到指定的路徑: {cache_path}")
        return

    print(f"{'模型名稱 (Model Name)':<45} | {'佔用空間 (Size)'}")
    print("-" * 65)

    total_cache_size = 0

    # 尋找所有以 'models--' 開頭的資料夾
    for item in cache_dir.iterdir():
        if item.is_dir() and item.name.startswith("models--"):
            # 將資料夾名稱還原為模型名稱 (例: models--google--gemma -> google/gemma)
            model_name = item.name.replace("models--", "").replace("--", "/")
            
            # 計算資料夾內的實體檔案大小
            model_size_bytes = 0
            for dirpath, _, filenames in os.walk(item):
                for f in filenames:
                    fp = os.path.join(dirpath, f)
                    # 略過 symlink，只計算真實檔案 (通常存在 blobs 資料夾內)
                    if not os.path.islink(fp):
                        model_size_bytes += os.path.getsize(fp)
            
            # 轉換為 GB (1 GB = 1024^3 Bytes)
            size_gb = model_size_bytes / (1024 ** 3)
            total_cache_size += size_gb
            
            print(f"{model_name:<45} | {size_gb:>6.2f} GB")

    print("-" * 65)
    print(f"{'總計 (Total)':<45} | {total_cache_size:>6.2f} GB")

if __name__ == "__main__":
    # 您的 Hugging Face 快取路徑
    TARGET_DIR = os.path.expanduser(
        os.environ.get("HF_HOME_HUB", "~/.cache/huggingface/hub")
    )
    get_model_sizes(TARGET_DIR)