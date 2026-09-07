[English](README.md) | **繁體中文**

# 對 eugr/spark-vllm-docker 的修改

[eugr/spark-vllm-docker](https://github.com/eugr/spark-vllm-docker) 是第三方專案，
**不是本人作品**。本目錄只保留我在自己環境上對它所做的修改。

## 內容

- `spark-vllm-docker.patch`——對 `Dockerfile.mxfp4` 與兩個既有 recipe 的修改
- `nemotron-3-super-fp8.yaml`——新增的 recipe，讓 Nemotron-3-Super-120B 的 FP8 量化版可在 DGX Spark 上啟動

## 套用方式

```bash
git clone https://github.com/eugr/spark-vllm-docker.git
cd spark-vllm-docker
git apply ../upstream/spark-vllm-docker.patch
cp ../upstream/nemotron-3-super-fp8.yaml recipes/
```

## TODO

這些修改目前只存在本地。若確認在乾淨環境可重現，應該整理成 PR 發回上游——
被合併的 PR 比一個 patch 檔更有說服力。
