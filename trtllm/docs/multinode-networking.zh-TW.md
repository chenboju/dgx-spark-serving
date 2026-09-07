[English](multinode-networking.md) | **繁體中文**

# 建立雙節點 QSFP 連線

兩台 DGX Spark 以 QSFP 直連，讓它們能當成單一邏輯裝置執行張量平行推論。
實體連線是通的，但 MPI job 就是連不到對方。以下是實際的問題所在，以及怎麼找出來的。

全文以 **node A** 與 **node B** 稱呼兩台機器，兩邊的網卡都是 `enp1s0f1np1`。

## 1. 先確認連線存在

```bash
ibdev2netdev
```

兩個節點都回報：

```
rocep1s0f1 port 1 ==> enp1s0f1np1 (Up)
```

所以線材與支援 RoCE 的 port 都沒問題，而 `enp1s0f1np1` 就是後續每個步驟都必須綁定的網卡。
每台 Spark 有兩個 port（`enp1s0f0np0`、`enp1s0f1np1`），只有接線的那個會顯示 `Up`。

## 2. 檢查位址

```bash
ip addr show enp1s0f1np1
```

問題就出在這裡：

| 節點 | 狀態 | IPv4 |
|------|------|------|
| B    | `UP` | `169.254.x.x/16`（自動取得） |
| A    | `UP` | **沒有**——完全沒有 `inet` 那一行 |

網卡可以在鏈路層是 `UP`，卻完全沒有 L3 位址。Node A 有 carrier 但沒有 IP，
所以鏈路層以上的東西全都不會動。**只看 `ip link` 會在兩邊都顯示 "up"，把問題藏起來**——
查 `ip addr` 而不是 `ip link`，是「兩分鐘找到」與「一直找不到」的差別。

## 3. 修正 node A 的位址

直連線材上沒有 DHCP server，所以唯一能配到位址的機制是 IPv4 link-local（RFC 3927）。
Node B 自己協商到了一個，node A 則沒有任何 netplan 設定去要求它這麼做。

```bash
sudo tee /etc/netplan/40-cx7.yaml > /dev/null <<'EOF'
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

兩個 port 都寫進去，是為了日後把線換到另一個 port 時設定仍然有效。
`chmod 600` 是必要的——netplan 會拒絕套用所有人可讀的設定檔。

Node A 隨後取得 `169.254.x.x/16` 位址，兩個節點終於在同一個網段上。

## 4. 主機之間的免密碼 SSH

MPI 透過 SSH 啟動遠端 rank，所以必須是非互動的。兩個節點當時都還沒有金鑰對。

```bash
# 兩個節點各自執行
ssh-keygen -t ed25519          # 不設 passphrase——mpirun 無法回答提示

# 在 A
ssh-copy-id -i ~/.ssh/id_ed25519.pub <user>@<node-B-ip>
# 在 B
ssh-copy-id -i ~/.ssh/id_ed25519.pub <user>@<node-A-ip>
```

信任關係必須是**雙向的**。任一節點都可能成為 head node，而
[`02-setup-mpi-ssh.sh`](../multi-node/02-setup-mpi-ssh.sh) 的容器設定會把
同一份 `authorized_keys` 複製進兩個容器——所以那個檔案裡必須事先就有兩把公鑰。

兩台機器的使用者名稱必須相同。MPI 預設的 rsh launcher 會以當前使用者連線，
不會額外指定。

## 5. 驗證

```bash
# 從 A
ssh <node-B-ip> hostname     # -> node B 的 hostname，不該跳密碼提示
# 從 B
ssh <node-A-ip> hostname     # -> node A 的 hostname，不該跳密碼提示
```

兩邊都通過之後，多節點啟動就正常了。

## 根本原因

Node A 從來沒有設定 IPv4 link-local，所以它有 carrier 卻沒有位址，
兩個節點從來不在同一個 L3 網段上。補上 netplan 設定、產生並交換 ed25519 金鑰後解決。

## 已知限制

Link-local 位址是開機時協商的，**跨重開機不保證穩定**。OpenMPI 的 hostfile
是逐字釘住這些位址的，所以重開機可能讓叢集無聲地壞掉。
在 QSFP 網段上改用靜態位址才是正解；目前還沒做。
