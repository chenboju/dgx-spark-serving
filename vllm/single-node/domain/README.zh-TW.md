[English](README.md) | **繁體中文**

# domain/ — 領域專用模型

針對特定學科微調過的模型，非通用對話用途。

| 腳本 | 模型 | 領域 |
|---|---|---|
| `llamat-3-chat-materials.sh` | `m3rg-iitd/llamat-3-chat` | 材料科學 |

## 關於 LLaMat-3

由 IIT Delhi 的 M3RG 實驗室在材料科學語料上微調的 LLaMA-3 衍生模型，
用於材料文獻的理解與問答。

搭配 [embedding/openscholar-retriever.sh](../embedding/openscholar-retriever.sh)
可組成學術文獻的檢索問答流程——retriever 負責召回論文段落，LLaMat 負責領域推理。

## 用法

```bash
source ../../.env
./llamat-3-chat-materials.sh
```
