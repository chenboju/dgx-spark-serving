[English](01-dual-node-networking.md) | **繁體中文**

# DGX Spark 雙節點 QSFP 連線排查

兩台 DGX Spark（Spark A、Spark B）以 QSFP 直連後，無法進行多節點通訊。本文記錄從實體層到 SSH 認證的完整排查流程。

## 環境

| 項目 | Spark A | Spark B |
|---|---|---|
| 主機名稱 | `gx10-bc71` | `gx10-46f3` |
| 高速網卡 IP | `169.254.203.69/16` | `169.254.215.60/16` |
| 網卡介面 | `enp1s0f1np1` | `enp1s0f1np1` |
| 使用者 | `lab0616` | `lab0616` |

兩台使用者名稱相同，這是後續 SSH 免密碼登入的前提。

## 排查流程

### 1. 實體連線與網卡狀態

先確認 QSFP 纜線正確連接、系統有抓到 RoCE 網卡：

```bash
ibdev2netdev
```

兩台皆顯示 `rocep1s0f1 port 1 ==> enp1s0f1np1 (Up)`，確認實體層正常，並選定 `enp1s0f1np1` 作為後續所有分散式通訊的介面。

### 2. IP 位址分配

```bash
ip addr show enp1s0f1np1
```

**發現問題**：

- Spark B 成功取得 link-local IP `169.254.215.60/16`
- Spark A 網卡狀態為 `UP`，但**沒有 `inet` 紀錄**——網卡活著卻沒有 IPv4 位址

這就是連線失敗的根因：網路層根本沒建立起來。

### 3. 修復 Spark A：套用 Netplan link-local 自動尋址

在 Spark A 建立 Netplan 設定檔：

```bash
sudo tee /etc/netplan/40-cx7.yaml > /dev/null <<EOF
network:
  version: 2
  ethernets:
    enp1s0f0np0:
      link-local: [ ipv4 ]
    enp1s0f1np1:
      link-local: [ ipv4 ]
EOF

sudo chmod 600 /etc/netplan/40-cx7.yaml
sudo netplan apply
```

Spark A 取得 `169.254.203.69/16`，雙方進入同一網段。

### 4. 設定雙向免密碼 SSH

Ray 叢集需要節點間免密碼互連。系統預設未產生金鑰，需從頭建立：

```bash
# 兩台分別執行，採預設值不設 passphrase
ssh-keygen
```

產生的是 `ed25519` 格式金鑰，路徑 `~/.ssh/id_ed25519.pub`。

交換公鑰：

```bash
# Spark A 執行
ssh-copy-id -i ~/.ssh/id_ed25519.pub lab0616@169.254.215.60

# Spark B 執行
ssh-copy-id -i ~/.ssh/id_ed25519.pub lab0616@169.254.203.69
```

### 5. 驗證

```bash
# 在 Spark A
ssh 169.254.215.60 hostname   # -> gx10-46f3

# 在 Spark B
ssh 169.254.203.69 hostname   # -> gx10-bc71
```

## 結論

連線失敗的主因是 **Spark A 未套用 Netplan 的 link-local 自動 IP 設定**，網卡雖然 `UP` 但缺少 IPv4 位址，導致網路層無法互通。補齊網路設定並建立、交換 ed25519 金鑰後，雙節點通訊恢復正常。

下一步：[在此叢集上部署 vLLM 跨節點推論](02-dual-node-vllm-deployment.zh-TW.md)
