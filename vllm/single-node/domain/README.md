**English** | [繁體中文](README.zh-TW.md)

# domain/ — domain-specific models

Models fine-tuned for a particular field, not for general conversation.

| Script | Model | Domain |
|---|---|---|
| `llamat-3-chat-materials.sh` | `m3rg-iitd/llamat-3-chat` | Materials science |

## About LLaMat-3

A LLaMA-3 derivative fine-tuned on materials-science corpora by the M3RG lab at
IIT Delhi, for understanding and answering questions about materials literature.

Paired with
[embedding/openscholar-retriever.sh](../embedding/openscholar-retriever.sh) it
forms a retrieval-QA flow over academic literature — the retriever pulls back
paper passages, LLaMat does the domain reasoning.

## Usage

```bash
source ../../.env
./llamat-3-chat-materials.sh
```
