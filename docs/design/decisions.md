# 設計判断・トレードオフ

## 概要

このドキュメントでは、データ分析プラットフォーム設計時に行った重要な技術判断とそのトレードオフについて記録します。

## アーキテクチャ判断

### 1. Kubernetes採用判断

#### 判断内容
従来のAnsible + 物理サーバ構成からKubernetes構成への移行

#### 採用理由
- **スケーラビリティ**: 動的なリソース管理とスケーリング
- **運用性**: 宣言的な設定管理とセルフヒーリング
- **標準化**: クラウドネイティブ技術スタックの採用

#### トレードオフ
| メリット | デメリット |
|----------|------------|
| 自動スケーリング | 学習コストの増加 |
| 障害自動復旧 | 複雑性の増加 |
| リソース効率化 | デバッグの困難さ |

### 2. 物理構成抽象化レベル

#### 判断内容
完全抽象化ではなく「部分抽象化」を採用

#### 背景
Hadoopのデータローカリティ要件と汎用性のバランス

#### 選択肢と判断

**完全抽象化**（不採用）
- **メリット**: 高い可搬性
- **デメリット**: データローカリティ性能劣化

**部分抽象化**（採用）
- **メリット**: 性能と可搬性のバランス
- **デメリット**: 設定の複雑さ

```yaml
# 採用した抽象化例
nodeSelector:
  workload: compute      # 抽象的な役割
  data-locality: enabled # 具体的な要件
```

## データローカリティ実現方式

### 判断内容
DaemonSet + HostNetwork方式を推奨として採用

### 選択肢比較

#### 1. DaemonSet + HostNetwork方式（推奨）

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

**判断根拠**:
- **完全なデータローカリティ**: 1ノード=1DataNode, hostPathによるアクセス
- **DNS整合性**: ホストネットワーク使用
- **シンプルな運用**: 複雑な設定不要

**トレードオフ**:
| メリット | デメリット |
|----------|------------|
| 最適な性能 | 柔軟性の制限 |
| 運用シンプル | HostNetwork依存 |
| DNS一貫性 | ポート競合リスク |

#### 2. StatefulSet + Local PV方式（代替案）

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: hadoop-datanode
spec:
  volumeClaimTemplates:
  - metadata:
      name: hadoop-data
    spec:
      storageClassName: local-storage
```

**判断根拠**:
- **動的スケーリング**: ノード数の柔軟な変更
- **Kubernetes標準**: Local Volume使用

**トレードオフ**:
| メリット | デメリット |
|----------|------------|
| 動的スケーリング | 複雑な設定 |
| 標準的な手法 | 再配置時の性能劣化 |

### 最終判断
**段階的導入**: 開発環境でStatefulSet、本番環境でDaemonSet

## CNI選択

### 判断内容
環境に応じた柔軟な選択を支援

### 選択肢と特徴

#### Calico（推奨 - 本番環境）
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: hadoop-security
spec:
  podSelector:
    matchLabels:
      app: hadoop
  policyTypes:
  - Ingress
  - Egress
```

**採用理由**:
- **ネットワークポリシー**: セキュリティ要件対応
- **性能**: 高いネットワーク性能

#### Flannel（推奨 - 開発環境）
**採用理由**:
- **シンプル**: 設定・トラブルシューティングが容易
- **軽量**: リソース使用量が少ない

## 認証・セキュリティ判断

### Kerberos統一認証

#### 判断内容
従来設計を継承し、Kerberos認証を維持

#### 採用理由
- **統一認証**: 全コンポーネントで一貫した認証
- **企業標準**: エンタープライズ環境での標準的選択

#### 実装方式
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: hadoop-keytabs
type: Opaque
data:
  nn.service.keytab: <base64-keytab>
  dn.service.keytab: <base64-keytab>
```

**判断根拠**:
- **Secret使用**: Kubernetesネイティブなシークレット管理
- **ファイルベース**: 従来の設定方式を維持

### SSL/TLS暗号化

#### 判断内容
全通信でSSL/TLS暗号化を実施

#### 証明書管理方式
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: hadoop-ssl-certs
data:
  keystore.jks: <base64-keystore>
  truststore.jks: <base64-truststore>
```

**理由**: Hadoopエコシステムの標準形式

## 開発環境設計

### Kind環境構成

#### ノード構成判断
```yaml
nodes:
- role: control-plane  # 1台
- role: worker        # 3台
```

**判断根拠**:
- **本番同等**: 本番環境と同じトポロジー
- **リソース効率**: 開発環境に適したリソース配分

#### リソース制限
```yaml
Control-plane: 4GB/2core
Worker:        2GB/1core
```

**判断根拠**:
- **実行可能**: 一般的な開発マシンで実行可能
- **機能検証**: 基本機能の検証には十分

## 運用方式判断

### デプロイメント戦略

#### GitOps vs 手動デプロイ
**採用**: 段階的GitOps導入

**Phase 1**: 手動デプロイ（現在）
```bash
kubectl apply -f k8s/
```

**Phase 2**: CI/CD統合（将来）
```yaml
on:
  push:
    paths:
    - 'k8s/**'
```

### 監視戦略

#### Prometheus + Grafana採用
**判断理由**:
- **Kubernetes統合**: ネイティブサポート
- **拡張性**: メトリクス収集の拡張性

## パフォーマンス判断

### リソース配分方針

#### メモリ配分ルール
```
システム予約:    物理メモリの12.5%
Kubernetes:      物理メモリの6.25%
アプリケーション: 残りの81.25%
```

**判断根拠**:
- **安定性**: システムリソース確保
- **効率性**: アプリケーション領域最大化

### ストレージ判断

#### HDFSブロックサイズ
```xml
<property>
  <name>dfs.blocksize</name>
  <value>134217728</value> <!-- 128MB -->
</property>
```

**判断根拠**:
- **バランス**: メタデータサイズと処理効率のバランス
- **互換性**: Spark等との最適な組み合わせ

## 今後の検討事項

### 短期（3ヶ月以内）
1. **監視強化**: Prometheus/Grafana統合
2. **ログ統合**: 集約ログシステム構築

### 中期（6ヶ月以内）
1. **GitOps導入**: ArgoCD等の検討
2. **セキュリティ強化**: OPA/Gatekeeper導入

### 長期（1年以内）
1. **マルチクラスタ**: 複数環境管理
2. **サービスメッシュ**: Istio等の検討
