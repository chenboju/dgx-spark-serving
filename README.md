**English** | [繁體中文](README.zh-TW.md)

# DGX Spark inference serving

Deployment scripts and debugging records for **single-node and two-node vLLM and TensorRT-LLM serving** on NVIDIA DGX Spark (GB10, ARM64, unified memory). Two Sparks connect directly over QSFP and run tensor parallelism through Ray or MPI-over-SSH.

The deliverables are traceable configurations, successful bring-up records, and fixes for ARM64 dependencies, container communication, and memory allocation. The work is complete and retained as an engineering record of a specific hardware setup.

## Deployment results

| Scope | Result | Verification boundary |
|---|---|---|
| Two-node vLLM | Qwen3-30B-A3B BF16 / 16K; GPT-OSS-120B MXFP4 + fp8 KV / 32K | Serving verified; cross-node performance not measured |
| Two-node TensorRT-LLM | Nemotron-3-Super-120B, Llama 4 Scout, GPT-OSS-120B | Serving verified; no benchmarks |
| Single-node vLLM | 26 scripts covering generation, embeddings, quantisation pairs, and speculative decoding | Per-model conditions documented in subdirectories |
| Single-node TensorRT-LLM | 5 models with shared launch logic | Per-model settings and limitations documented in subdirectories |

The two-node vLLM **Nemotron NVFP4 / FP8 scripts have not been successfully verified** and remain as debugging records. MTP / DFlash and quantisation configurations have no measured speedup, acceptance-rate, or quality comparisons.

## Getting started

Prepare the DGX Spark NVIDIA driver, GPU-enabled Docker, and the selected model and container. Scripts retain the original image tags, interfaces, IP addresses, cache locations, and memory settings; adapt these to your machine before running.

Prepare the vLLM environment from this repository's root:

```bash
cp vllm/.env.example .env
# Edit .env to set HF_TOKEN and VLLM_API_KEY
source .env
```

If GPT-OSS-120B is fully cached under `~/.cache/huggingface/`, this single-node entry point can be used. It loads offline by default and does not download missing weights:

```bash
bash vllm/single-node/gpt-oss/gpt-oss-120b-mxfp4.sh
```

| Goal | Entry point |
|---|---|
| Choose another single-node vLLM model | [Single-node index](vllm/single-node/README.md) |
| Build a two-Spark Ray cluster | [Two-node startup sequence](vllm/cluster/README.md) |
| Use TensorRT-LLM | [Environment and startup guide](trtllm/README.md) |

## Engineering highlights

- **Networking and container communication:** diagnosing QSFP carrier without usable IPv4, distributed frameworks selecting the wrong interface, and MPI requiring an in-container sshd to launch remote ranks. See the [vLLM networking record](vllm/docs/01-dual-node-networking.md) and [TRT-LLM networking record](trtllm/docs/multinode-networking.md).
- **Unified memory allocation:** weights, loading buffers, communication buffers, and KV cache share one memory pool. The records cover failures caused by Ray's memory monitor and parallel weight loading, and the resulting settings. See the [vLLM deployment record](vllm/docs/02-dual-node-vllm-deployment.md) and [TRT-LLM tuning notes](trtllm/docs/tuning-notes.md).
- **Speculative decoding integration:** image configuration, source overlays, and tokenizer loading for MTP / DFlash. See the [speculative decoding index](vllm/single-node/speculative-decoding/README.md).

## Repository layout

```text
.
├── README.md / README.zh-TW.md
├── vllm/
│   ├── cluster/       # Two-node Ray, smoke checks, third-party vendor script
│   ├── single-node/   # Generation, embeddings, quantisation, speculative decoding
│   ├── docs/          # Networking and deployment records
│   ├── tools/         # Hugging Face downloads and cache reports
│   └── upstream/      # Patches and recipes for third-party projects
├── trtllm/
│   ├── single-node/   # 5 models and shared launch logic
│   ├── multi-node/    # MPI-over-SSH, setup, and connectivity checks
│   ├── tools/         # Backend checks and Open WebUI
│   └── docs/          # Networking and memory tuning
└── LICENSE
```

50 Markdown files form 25 English / Traditional Chinese pairs. Full framework indexes: [vLLM](vllm/README.md), [TensorRT-LLM](trtllm/README.md).

## Performance data and limitations

The companion project **llm-serving-benchmark** contains single-node vLLM measurements for GPT-OSS-20B / 120B and comparisons between RTX 4090 and DGX Spark. Those results do not establish performance for this project's two-node or TensorRT-LLM configurations.

Single-node versus two-node scaling, vLLM versus TensorRT-LLM performance, speculative decoding speedup, and quantisation quality differences were not measured here. Successful bring-up does not establish general-purpose deployment defaults. Some two-node TRT-LLM configurations use TCP fallback and SSH settings for an isolated direct link; see the framework documentation.

## Licence and provenance

Original content uses the [MIT licence](LICENSE). [vendor/](vllm/cluster/vendor/README.md) contains the unmodified vLLM `run_cluster.sh` (Apache-2.0); [upstream/](vllm/upstream/README.md) records changes to eugr/spark-vllm-docker and their provenance. Models, containers, and third-party code retain their respective licences.
