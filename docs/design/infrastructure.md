# 物理構成要件・ノード設計

## 概要

本システムでは、物理構成を抽象化し、ノード群の役割と特性を定義することで、様々な物理環境に対応可能な設計を採用しています。

## ノード群の分類

### Control Plane群
**役割**: Kubernetesクラスタの管理機能および軽量なアプリケーション

**ラベル**:
```yaml
node-role.kubernetes.io/control-plane: ""
workload: management
```

**配置するコンポーネント**:
- Kubernetes APIサーバー、etcd、kube-scheduler
- Hadoop NameNode、ResourceManager
- JupyterHub Hub、Airflow Webserver

**要件**:
- **台数**: 3台（高可用性）
- **CPU**: 4コア以上
- **メモリ**: 8GB以上

### Compute群
**役割**: データ処理・計算ワークロード実行

**ラベル**:
```yaml
workload: compute
data-locality: enabled
```

**配置するコンポーネント**:
- Hadoop DataNode（DaemonSet）
- Spark Executor Pod
- JupyterHub SingleUser Pod

**要件**:
- **台数**: 3台以上（スケーラブル）
- **CPU**: 8コア以上
- **メモリ**: 32GB以上

## データローカリティ実現

### DaemonSet + HostNetwork方式（推奨）
```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: hadoop-datanode
spec:
  template:
    spec:
      hostNetwork: true
      nodeSelector:
        workload: compute
```

**特徴**:
- 各Computeノードに必ず1つのDataNode
- 完全なデータローカリティ実現

### StatefulSet + Local PV方式
```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: datanode-pv-node1
spec:
  capacity:
    storage: 1Ti
  storageClassName: local-storage
  local:
    path: /data/hadoop
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - compute-node-1
```

## ネットワーク要件

### CNI選択
- **Calico**: ネットワークポリシー対応
- **Flannel**: シンプル構成
- **Cilium**: 高性能・セキュリティ重視

### ポート要件
```yaml
# HDFS
- port: 9000   # NameNode IPC
- port: 9870   # NameNode HTTP
- port: 9864   # DataNode HTTP

# YARN
- port: 8088   # ResourceManager HTTP
- port: 19888  # JobHistoryServer HTTP
```

## ストレージ要件

### StorageClass設計
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
```

### 用途別ストレージ配分
- **etcd**: 高速SSD（10GB程度）
- **HDFS**: 大容量HDD/SSD（環境依存）
- **ログ**: 中容量SSD（100GB程度）

## 開発環境での簡略化

### Kind環境設定
```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "workload=management"
- role: worker
  labels:
    workload: compute
    data-locality: enabled
```

### リソース制限
- **Control-plane**: 4GB/2core
- **Worker**: 2GB/1core