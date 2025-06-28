# Kubernetes Infrastructure Automation

本番環境でのKubernetesクラスター構築用のAnsible設定です。

## 構成

```
infra/ansible/
├── ansible.cfg              # Ansible設定ファイル
├── inventories/             # インベントリファイル
│   └── production/          # 本番環境用設定
│       ├── hosts            # ホスト定義
│       └── group_vars/      # グループ変数
├── playbooks/               # Playbook
│   ├── k8s-install.yaml     # Kubernetesインストール
│   └── k8s-setup.yaml       # クラスター初期設定
└── roles/                   # Role定義
    ├── container-runtime/   # Docker/containerdインストール
    ├── kubernetes/          # Kubernetes設定
    └── networking/          # CNI設定
```

## 前提条件

### システム要件
- Ubuntu 20.04 LTS 以上
- 最小構成: 2GB RAM, 2 CPU cores
- 推奨構成: 4GB RAM, 4 CPU cores

### 必要なツール
- Ansible 2.9以上
- SSH秘密鍵（パスワードレスアクセス）
- sudoアクセス権限

## セットアップ手順

### 1. インベントリファイルの設定

`inventories/production/hosts`を編集してサーバー情報を設定:

```ini
[k8s_master]
master-01 ansible_host=192.168.1.10 ansible_user=ubuntu

[k8s_worker]
worker-01 ansible_host=192.168.1.11 ansible_user=ubuntu
worker-02 ansible_host=192.168.1.12 ansible_user=ubuntu
```

### 2. SSH接続の確認

```bash
# 接続テスト
ansible all -m ping

# sudo権限の確認
ansible all -m shell -a "sudo whoami"
```

### 3. Kubernetesクラスターのインストール

```bash
# インフラ構築（Docker、Kubernetes、CNI）
ansible-playbook playbooks/k8s-install.yaml

# 基本コンポーネントの設定
ansible-playbook playbooks/k8s-setup.yaml
```

## Playbook詳細

### k8s-install.yaml
- Container Runtime（Docker）のインストール
- Kubernetes（kubelet、kubeadm、kubectl）のインストール
- マスターノードの初期化
- ワーカーノードのクラスター参加
- CNI（Calico）の設定

### k8s-setup.yaml
- Storage Provisioner（Local Path）の設定
- Metrics Serverの設定
- Ingress Controller（NGINX）の設定
- Cert-Managerの設定
- データプラットフォーム用ネームスペースの作成
- RBAC設定
- ResourceQuotaの設定

## 設定カスタマイズ

### Kubernetes設定
`inventories/production/group_vars/all/main.yaml`で調整可能:

```yaml
kubernetes_version: "1.28"
kubernetes_pod_subnet: "10.244.0.0/16"
kubernetes_service_subnet: "10.96.0.0/12"
cni_provider: "calico"
```

### リソース制限
ワーカーノード用: `inventories/production/group_vars/k8s_worker/main.yaml`

```yaml
node_resources:
  cpu_limit: "8"
  memory_limit: "16Gi"
```

## 運用コマンド

```bash
# クラスター状態確認
kubectl get nodes -o wide
kubectl get pods --all-namespaces

# ストレージクラス確認
kubectl get storageclass

# Ingress確認
kubectl get svc -n ingress-nginx

# リソース使用状況
kubectl top nodes
kubectl top pods --all-namespaces
```

## トラブルシューティング

### よくある問題

1. **ノードがNotReady状態**
   ```bash
   kubectl describe node <node-name>
   journalctl -u kubelet
   ```

2. **CNIポッドが起動しない**
   ```bash
   kubectl logs -n calico-system -l k8s-app=calico-node
   ```

3. **Ingress Controllerにアクセスできない**
   ```bash
   kubectl get svc -n ingress-nginx
   # NodePortでアクセス: http://<node-ip>:<nodeport>
   ```

### ログ確認

```bash
# Ansible実行ログ
ansible-playbook playbooks/k8s-install.yaml -v

# Kubernetesコンポーネントログ
journalctl -u kubelet
journalctl -u docker
```

## 次のステップ

クラスター構築完了後:

1. データプラットフォームアプリケーションのデプロイ（Helm使用）
2. 監視システムの設定（Prometheus/Grafana）
3. ログ集約システムの設定
4. バックアップシステムの設定

## セキュリティ考慮事項

- SSH鍵の適切な管理
- sudo権限の最小化
- ネットワークポリシーの有効化
- RBAC設定の適用
- 定期的なセキュリティアップデート