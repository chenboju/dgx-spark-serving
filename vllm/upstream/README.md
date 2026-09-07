**English** | [繁體中文](README.zh-TW.md)

# Modifications to eugr/spark-vllm-docker

[eugr/spark-vllm-docker](https://github.com/eugr/spark-vllm-docker) is a
third-party project and **not my work**. This directory holds only the changes I
made to it in my own environment.

## Contents

- `spark-vllm-docker.patch` — changes to `Dockerfile.mxfp4` and two existing recipes
- `nemotron-3-super-fp8.yaml` — a new recipe that gets the FP8 quantised
  Nemotron-3-Super-120B to start on DGX Spark

## Applying

```bash
git clone https://github.com/eugr/spark-vllm-docker.git
cd spark-vllm-docker
git apply ../upstream/spark-vllm-docker.patch
cp ../upstream/nemotron-3-super-fp8.yaml recipes/
```

## TODO

These changes exist only locally. Once confirmed reproducible in a clean
environment they should be turned into a PR back upstream — a merged PR carries
more weight than a patch file.
