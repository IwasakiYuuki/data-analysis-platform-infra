# データ基盤システム構成

## 概要

Kubernetes上に構築されるデータ分析プラットフォームは、Hadoop、Spark、JupyterHub、Airflowを統合した分散処理・分析環境です。

## システム構成図

```
┌─────────────────────────────────────────┐
│         データ分析プラットフォーム        │
├─────────────────────────────────────────┤
│  ┌─────────┐ ┌─────────┐ ┌─────────┐    │
│  │ Airflow │ │JupyterHub│ │ Spark   │    │
│  │(Workflow)│ │(Notebook)│ │(Process)│    │
│  └─────────┘ └─────────┘ └─────────┘    │
│         │         │         │           │
│         └─────────┼─────────┘           │
│                   │                     │
│  ┌─────────────────────────────────┐     │
│  │          Hadoop Core            │     │
│  │  ┌─────────┐ ┌─────────────┐    │     │
│  │  │NameNode │ │ResourceMgr │    │     │
│  │  │         │ │   (YARN)   │    │     │
│  │  └─────────┘ └─────────────┘    │     │
│  │                                 │     │
│  │  ┌─────────┐ ┌─────────┐ ┌───── │     │
│  │  │DataNode │ │DataNode │ │Data  │     │
│  │  │(Worker1)│ │(Worker2)│ │Node3)│     │
│  │  └─────────┘ └─────────┘ └───── │     │
│  └─────────────────────────────────┘     │
└─────────────────────────────────────────┘
```

## コンポーネント詳細

### 1. Hadoop Core

#### HDFS（分散ファイルシステム）

**NameNode**:
- **配置**: Control Plane（高可用性構成）
- **機能**: メタデータ管理、ファイルシステム操作
- **高可用性**: Active/Standby構成

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: hadoop-namenode
spec:
  replicas: 2  # Active/Standby
  template:
    spec:
      nodeSelector:
        workload: management
```

**DataNode**:
- **配置**: Compute群（DaemonSetまたはStatefulSet）
- **機能**: 実際のデータ格納・読み書き
- **データローカリティ**: 計算処理と同一ノード配置

### 2. Apache Spark

#### Spark on YARN構成
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: spark-config
data:
  spark-defaults.conf: |
    spark.master yarn
    spark.hadoop.fs.defaultFS hdfs://hadoop-namenode:9000
    spark.eventLog.enabled true
```

#### Spark Executor配置
- **動的配置**: ワークロードに応じたExecutor数調整
- **メモリ最適化**: ノードメモリの60-80%をSpark用に配分

### 3. JupyterHub

#### Hub配置
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jupyterhub-hub
spec:
  template:
    spec:
      nodeSelector:
        workload: management
```

#### SingleUser Pod配置
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: jupyterhub-config
data:
  jupyterhub_config.py: |
    c.KubeSpawner.node_selector = {"workload": "compute"}
    c.KubeSpawner.cpu_limit = 2
    c.KubeSpawner.mem_limit = "4G"
```

### 4. Apache Airflow

#### Airflow Scheduler/Webserver
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: airflow-scheduler
spec:
  template:
    spec:
      nodeSelector:
        workload: management
      containers:
      - name: scheduler
        image: apache/airflow:2.8.0
        env:
        - name: AIRFLOW__CORE__EXECUTOR
          value: "KubernetesExecutor"
```

## セキュリティ統合

### Kerberos認証

**KDC（Key Distribution Center）**:
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: kerberos-kdc
spec:
  template:
    spec:
      nodeSelector:
        workload: management
```

**プリンシパル設定**:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: hadoop-keytabs
type: Opaque
data:
  nn.service.keytab: <base64-encoded-keytab>
  dn.service.keytab: <base64-encoded-keytab>
```

### SSL/TLS暗号化
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: hadoop-ssl-certs
type: Opaque
data:
  keystore.jks: <base64-encoded-keystore>
  truststore.jks: <base64-encoded-truststore>
```

## データフロー

### 1. データ投入
```
外部データ → Airflow → HDFS
```

### 2. データ処理
```
HDFS → Spark → 処理済みデータ → HDFS
```

### 3. データ分析
```
HDFS → JupyterHub → 分析結果
```

## パフォーマンス設計

### リソース配分指針

#### CPU配分
```yaml
NameNode:        2 cores
ResourceManager: 2 cores
DataNode:        4 cores
Spark:           可変 (YARN管理)
```

#### メモリ配分（32GBノード例）
```yaml
システム:    4GB
NameNode:    4GB
DataNode:    4GB
YARN容量:    18GB (Spark等用)
```

### ストレージ最適化

#### HDFS設定
```xml
<configuration>
  <property>
    <name>dfs.blocksize</name>
    <value>134217728</value> <!-- 128MB -->
  </property>
  <property>
    <name>dfs.replication</name>
    <value>3</value>
  </property>
</configuration>
```

## 監視・ログ統合

### メトリクス収集
```yaml
apiVersion: v1
kind: Service
metadata:
  name: hadoop-metrics
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "8080"
```

### ログ管理
```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluentd-hadoop
spec:
  template:
    spec:
      containers:
      - name: fluentd
        volumeMounts:
        - name: hadoop-logs
          mountPath: /var/log/hadoop
```

## 開発・本番環境での差異

### 開発環境（Kind）
- **リソース制限**: 最小構成
- **レプリケーション**: 1-2
- **永続化**: emptyDir使用可能

### 本番環境
- **高可用性**: 全コンポーネント冗長化
- **リソース**: 十分な物理リソース

## 統合テスト

### 機能テスト
```bash
# HDFS書き込み/読み取りテスト
hdfs dfs -put test.txt /test/
hdfs dfs -get /test/test.txt

# Spark SQL テスト
spark-sql --master yarn -e "SELECT COUNT(*) FROM test_table"
```