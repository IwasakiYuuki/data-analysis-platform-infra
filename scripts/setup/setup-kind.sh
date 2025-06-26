#!/bin/bash
# Kind cluster setup script for Data Analysis Platform

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "🚀 Data Analysis Platform - Kind クラスター構築開始"
echo "📂 Project root: $PROJECT_ROOT"

# Check required tools
echo "🔍 必要なツールの確認..."
for tool in docker kind kubectl helm; do
    if ! command -v $tool &> /dev/null; then
        echo "❌ $tool がインストールされていません"
        exit 1
    fi
    echo "✅ $tool: $(which $tool)"
done

# Check if cluster already exists
if kind get clusters | grep -q "data-platform"; then
    echo "⚠️  data-platform クラスターが既に存在します"
    read -p "削除して再作成しますか？ (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🗑️  既存クラスターを削除中..."
        kind delete cluster --name data-platform
    else
        echo "❌ セットアップを中止します"
        exit 1
    fi
fi

# Create kind cluster
echo "📦 Kind クラスターを作成中..."
kind create cluster --config "$PROJECT_ROOT/dev/kind/cluster-config.yaml"

# Wait for cluster to be ready
echo "⏳ クラスターの準備完了を待機中..."
kubectl wait --for=condition=Ready nodes --all --timeout=300s

# Install CNI (Calico)
echo "🌐 Calico CNI をインストール中..."
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml

# Install Ingress Controller (nginx)
echo "🌍 Ingress Controller をインストール中..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# Wait for ingress controller to be ready
echo "⏳ Ingress Controller の準備完了を待機中..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=300s

# Create namespaces
echo "🏗️  Namespace を作成中..."
kubectl create namespace data-platform || true
kubectl create namespace monitoring || true
kubectl create namespace storage || true

# Label nodes
echo "🏷️  ノードにラベルを設定中..."
# Get node names
NODES=($(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'))

# Label the first worker node for Hadoop workloads
if [ ${#NODES[@]} -gt 1 ]; then
    kubectl label nodes ${NODES[1]} workload=hadoop --overwrite || true
fi

# Label the second worker node for Hadoop workloads
if [ ${#NODES[@]} -gt 2 ]; then
    kubectl label nodes ${NODES[2]} workload=hadoop --overwrite || true
fi

# Label the third worker node for services
if [ ${#NODES[@]} -gt 3 ]; then
    kubectl label nodes ${NODES[3]} workload=services --overwrite || true
fi

# Install local storage provisioner
echo "💾 Local Storage Provisioner をインストール中..."
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.24/deploy/local-path-storage.yaml

# Set local-path as default storage class
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# Install Metrics Server
echo "📊 Metrics Server をインストール中..."
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Patch metrics server for kind
kubectl patch deployment metrics-server -n kube-system --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/args/-",
    "value": "--kubelet-insecure-tls"
  },
  {
    "op": "add", 
    "path": "/spec/template/spec/containers/0/args/-",
    "value": "--kubelet-preferred-address-types=InternalIP"
  }
]'

# Show cluster info
echo ""
echo "✅ Kind クラスター構築完了！"
echo ""
echo "📋 クラスター情報:"
kubectl cluster-info
echo ""
echo "🔍 ノード一覧:"
kubectl get nodes -o wide
echo ""
echo "📦 ポート転送設定:"
echo "  - HTTP Ingress:    http://localhost:8080"
echo "  - HTTPS Ingress:   https://localhost:8443"
echo "  - Hadoop NameNode: http://localhost:9871"
echo "  - ResourceManager: http://localhost:8088"
echo "  - JupyterHub:      http://localhost:8000"
echo "  - Airflow:         http://localhost:8081"
echo "  - Spark History:   http://localhost:18080"
echo ""
echo "🔧 次のステップ:"
echo "  1. 依存サービス起動: docker-compose -f dev/docker-compose.yaml up -d"
echo "  2. アプリケーションデプロイ: ./scripts/deploy/deploy-dev.sh"
echo ""