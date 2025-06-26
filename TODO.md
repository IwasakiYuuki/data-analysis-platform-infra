# Kubernetes移行 TODO

現在のAnsibleベース構成からKubernetes構成への移行手順

## Phase 1: プロジェクト構造準備 🏗️

### 1.1 ディレクトリ構造の整備
- [x] `infrastructure/` ディレクトリ作成（Kubernetesクラスター構築用）
- [x] `k8s/` ディレクトリ作成（アプリケーション層）
- [x] `dev/` ディレクトリ作成（開発環境用）
- [x] `config/` ディレクトリ作成（設定・シークレット管理）
- [x] `scripts/` ディレクトリ作成（自動化スクリプト）
- [x] 既存構成を `legacy/` に移動

### 1.2 開発環境の準備
- [x] Kind（Kubernetes in Docker）設定ファイル作成
  - [x] cluster-config.yaml（フル構成）
  - [x] cluster-config-light.yaml（軽量構成）
  - [x] featureGates問題の解決
- [x] 新しいdocker-compose.yaml作成（K8s開発用）
- [x] 必要なツールの確認・インストール
  - [x] kubectl
  - [x] helm
  - [x] kustomize
  - [x] kind

## Phase 2: Kubernetesクラスター構築（インフラ層） ⚙️

### 2.1 Ansible Playbook作成
- [ ] `infrastructure/ansible/roles/kubernetes/` 作成
  - [ ] kubeletインストール
  - [ ] kubeadmインストール
  - [ ] kubectl設定
- [ ] `infrastructure/ansible/roles/container-runtime/` 作成
  - [ ] containerdインストール・設定
- [ ] `infrastructure/ansible/roles/networking/` 作成
  - [ ] CNI（Calico/Flannel）設定
- [ ] `infrastructure/ansible/roles/storage/` 作成
  - [ ] StorageClass設定
  - [ ] PersistentVolume設定

### 2.2 クラスター初期化
- [ ] `infrastructure/ansible/playbooks/k8s-install.yaml` 作成
- [ ] `infrastructure/ansible/playbooks/k8s-setup.yaml` 作成
- [ ] インベントリファイルの更新（K8sノード用）

### 2.3 基本的なK8sコンポーネント
- [ ] Ingress Controller導入
- [ ] Cert-Manager導入（SSL証明書自動化）
- [ ] Metrics Server導入
- [ ] Storage Provisioner設定

## Phase 3: データ分析基盤のHelm化 📦

### 3.1 Hadoopクラスター
- [ ] `helm/charts/hadoop-cluster/` 作成
  - [ ] Chart.yaml作成
  - [ ] values.yaml作成（デフォルト設定）
  - [ ] templates/namenode-deployment.yaml
  - [ ] templates/datanode-statefulset.yaml
  - [ ] templates/configmap.yaml（hadoop設定）
  - [ ] templates/service.yaml
  - [ ] templates/ingress.yaml
- [ ] Kerberos認証のK8s化
  - [ ] Secret作成（keytab）
  - [ ] InitContainer for kinit
- [ ] SSL/TLS証明書のSecret化

### 3.2 Sparkクラスター
- [ ] `helm/charts/spark-operator/` 作成
  - [ ] Spark Operator導入
  - [ ] SparkApplication CRD設定
  - [ ] History Server設定

### 3.3 JupyterHub
- [ ] `helm/charts/jupyterhub/` 作成
  - [ ] JupyterHub Helm Chart統合
  - [ ] Hadoop/Spark連携設定
  - [ ] Kerberos認証統合
  - [ ] PVC設定（ユーザーデータ永続化）

### 3.4 Airflow
- [ ] `helm/charts/airflow/` 作成
  - [ ] Apache Airflow Helm Chart統合
  - [ ] Executor設定（KubernetesExecutor）
  - [ ] DAG同期設定
  - [ ] Hadoop/Spark連携

### 3.5 統合チャート
- [ ] `helm/charts/data-platform/` 作成
  - [ ] dependencies設定（サブチャート）
  - [ ] 全体設定の統合
  - [ ] values.yaml統合

## Phase 4: Kustomizeで環境差異管理 🔧

### 4.1 基本構造
- [ ] `k8s/base/kustomization.yaml` 作成
- [ ] Helmチャート統合設定

### 4.2 開発環境設定
- [ ] `k8s/environments/dev/` 作成
  - [ ] kustomization.yaml
  - [ ] values-dev.yaml（リソース少なめ）
  - [ ] ingress設定（dev用ドメイン）

### 4.3 本番環境設定
- [ ] `k8s/environments/prod/` 作成
  - [ ] kustomization.yaml
  - [ ] values-prod.yaml（高可用性・高性能）
  - [ ] ingress設定（prod用ドメイン）
  - [ ] monitoring設定強化

## Phase 5: 設定・シークレット管理 🔐

### 5.1 設定ファイル移行
- [ ] `config/kerberos/` 作成
  - [ ] krb5.conf
  - [ ] keytabファイルのSecret化
- [ ] `config/ssl/` 作成
  - [ ] 証明書のSecret化
  - [ ] cert-manager統合

### 5.2 外部依存関係
- [ ] データベース接続設定（Hive Metastore用）
- [ ] 外部ストレージ設定（S3/MinIO等）
- [ ] 監視システム連携（Prometheus/Grafana）

## Phase 6: テスト・検証 🧪

### 6.1 機能テスト
- [ ] Hadoop HDFS操作テスト
- [ ] Spark ジョブ実行テスト
- [ ] JupyterHub ログイン・Notebook実行テスト
- [ ] Airflow DAG実行テスト
- [ ] 各サービス間連携テスト

### 6.2 パフォーマンステスト
- [ ] 既存環境との処理性能比較
- [ ] リソース使用量測定
- [ ] スケーラビリティテスト

### 6.3 セキュリティテスト
- [ ] Kerberos認証テスト
- [ ] SSL/TLS通信テスト
- [ ] RBAC設定テスト

## Phase 7: 運用準備 🚀

### 7.1 自動化スクリプト
- [ ] `scripts/setup-k8s.sh` 作成
- [ ] `scripts/deploy-apps.sh` 作成
- [ ] `scripts/backup/` スクリプト群作成

### 7.2 監視・ログ
- [ ] Prometheus/Grafana導入
- [ ] ログ集約システム（ELK/Loki）
- [ ] アラート設定

### 7.3 ドキュメント更新
- [ ] README.md更新
- [ ] CLAUDE.md更新
- [ ] 運用手順書作成
- [ ] トラブルシューティングガイド

## Phase 8: 本番移行 📈

### 8.1 段階的移行
- [ ] 開発環境での動作確認
- [ ] ステージング環境での統合テスト
- [ ] 本番環境での並行稼働テスト

### 8.2 データ移行
- [ ] HDFS データ移行計画
- [ ] ユーザーデータ移行
- [ ] 設定データ移行

### 8.3 切り替え・後処理
- [ ] DNS切り替え
- [ ] ユーザー向けアナウンス
- [ ] 旧環境の段階的停止
- [ ] `legacy/` フォルダ削除

## 優先度

- **高**: Phase 1, 2（基盤整備）
- **中**: Phase 3, 4（アプリケーション移行）
- **低**: Phase 5-8（運用・移行）

## 想定期間

- **Phase 1-2**: 2-3週間
- **Phase 3-4**: 4-6週間  
- **Phase 5-8**: 2-4週間

**総計**: 約2-3ヶ月

## 注意事項

- 各Phaseは並行して進められる部分もある
- 既存システムを停止せずに段階的移行を推奨
- テスト環境での十分な検証が必要
- バックアップ・ロールバック計画も重要
