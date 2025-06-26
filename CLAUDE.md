# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

このファイルは、このリポジトリでコードを操作する際のClaude Codeに向けたガイダンスです。日本語で応答してください。

## プロジェクト概要

このリポジトリは、オンプレミス環境でのデータ分析プラットフォームのIaC（Infrastructure as Code）です。
Ansibleを使用してHadoop、Spark、JupyterHub、Airflowクラスターを構築・管理します。

## アーキテクチャ

### コンポーネント構成
- **Hadoop**: 分散ストレージ・処理基盤（Kerberos認証付き）
- **Spark**: 分散処理エンジン
- **JupyterHub**: データサイエンス開発環境
- **Airflow**: ワークフロー管理

### インフラ構成
- **Management Node**: Ansibleによる管理ノード
- **Hadoop Nodes**: NameNode/DataNodeの実際のサーバー
- **Development Environment**: Docker Composeによる開発環境

## よく使用するコマンド

### 開発環境の起動・停止
```bash
# 開発環境コンテナの起動
docker compose up -d

# 開発環境コンテナの停止
docker compose down
```

### プラットフォームのデプロイ
```bash
# 開発環境へのインストール
ansible-playbook -i inventories/dev/hosts playbooks/install.yaml

# 本番環境へのインストール
ansible-playbook -i inventories/prod/hosts playbooks/install.yaml

# クラスター初期化（初回のみ）
ansible-playbook -i inventories/dev/hosts playbooks/setup.yaml

# クラスター開始
ansible-playbook -i inventories/dev/hosts playbooks/start.yaml

# クラスター停止
ansible-playbook -i inventories/dev/hosts playbooks/stop.yaml
```

### ユーザー管理
```bash
# Hadoop用ユーザーを追加
ansible-playbook -i inventories/dev/hosts playbooks/add_user.yaml -e "user_name=<user>"
```

## 設定ファイル構造

### 重要な設定ファイル
- `inventories/(dev|prod)/hosts`: Ansibleインベントリファイル
- `roles/*/defaults/main.yaml`: 各コンポーネントのデフォルト設定
- `roles/*/vars/main.yaml`: 各コンポーネントの変数定義
- `docker-compose.yaml`: 開発環境の定義

### 事前準備が必要なファイル
- `roles/hadoop/files/keytab/`: Kerberos keytabファイル
- `roles/hadoop/files/jks/`: SSL証明書（JKS形式）
- `roles/airflow/files/`: Airflow用設定ファイル
- `inventories/*/group_vars/all/secrets.yaml`: 秘密情報（templatedあり）

## セキュリティ設定

### Kerberos認証
- Default Realm: HOME
- 各サービス用のkeytabファイルが必要
- SSL/TLS暗号化がデフォルトで有効

### 設定されるプリンシパル
- NameNode: `nn/_HOST@HOME`
- DataNode: `dn/_HOST@HOME`
- ResourceManager: `rm/_HOST@HOME`
- NodeManager: `nm/_HOST@HOME`
- JobHistoryServer: `jhs/_HOST@HOME`

## Ansible Roles構造

### 主要なRole
- `krb`: Kerberos設定
- `java`: Java環境セットアップ
- `hadoop`: Hadoop基盤
- `spark`: Spark設定
- `hive`: Hive設定
- `jupyterhub`: JupyterHub設定
- `airflow`: Airflow設定

### デプロイ順序
1. Kerberos設定
2. Java環境構築
3. Hadoop基盤インストール
4. Spark、Hive、JupyterHub、Airflowの各コンポーネント

## トラブルシューティング

### 初回起動時の注意点
- JobHistoryServerで無視可能なエラーが発生することがある
- HDFSディレクトリが未作成のためだが、setup.yamlで解決される

### ログ確認
```bash
# systemdサービスのログ確認
sudo journalctl -u hadoop-namenode
sudo journalctl -u hadoop-datanode
sudo journalctl -u hadoop-resourcemanager
sudo journalctl -u hadoop-nodemanager
sudo journalctl -u hadoop-historyserver
```

## 開発時の注意点

- 設定変更時は対応するtemplate（.j2）ファイルを編集する
- 秘密情報はsecrets.yamlに記載し、テンプレートファイルは.templateとして管理
- Docker環境では`ansible_connection=docker`を使用
- keytabファイルやSSL証明書は事前に準備が必要

## Kubernetes移行時の検討事項

### データローカリティの実現方式

#### 1. DaemonSet + HostNetwork方式（推奨）
- **利点**: 完全なデータローカリティ、DNS整合性
- **構成**: HostNetwork使用、HostPath永続化
- **DataNode識別**: ノード名=DNS名で一貫性保証

#### 2. StatefulSet + Local PV方式
- **利点**: 動的スケーリング対応
- **構成**: Local Volume Provisioner、WaitForFirstConsumer
- **注意**: 再配置時のデータローカリティ考慮必要

#### 3. 通常のStatefulSet + PVC方式
- **注意**: データローカリティが失われる可能性
- **問題**: PodとPVCが異なるノードに配置される場合あり

## 開発環境（Kind）設定方針

### 基本構成
- **ノード構成**: Control-plane 1台 + Worker 3台（本番環境と同じトポロジー）
- **リソース**: Control-plane 4GB/2core, Worker 1GB/1core
- **データ永続化**: 各ノード10GB程度のテスト用PVC

### 設計決定事項
1. **コンポーネント配置**
   - NameNode: Control-planeに配置（taint削除）
   - ResourceManager: Control-planeに配置
   - JupyterHub/Airflow: Control-planeに配置
   - DataNode: 各Workerに1つずつ（1Node=1DataNode）

2. **ネットワーク設定**
   - CNI: kindnet（デフォルト）
   - ホスト名: 固定ホスト名を使用予定
   - 外部アクセス: extraPortMappingsでブラウザアクセス対応

3. **開発体験**
   - Skaffoldを選択肢として検討
   - ファイル変更の自動検知・ビルド・デプロイ
   - 統合ログ表示機能

### Kind設定上の注意点
- featureGates設定でkubelet起動に問題が発生する場合があるため、不要な機能は無効化
- リソース制限はDocker側で設定（Memory: 8GB, CPU: 6core推奨）

### 本番環境との一貫性
- **アーキテクチャ**: 同じノード数・役割分担
- **設定ファイル**: Hadoop設定ファイルの共通化
- **デプロイ方法**: 同じkubectl apply方式
- **セキュリティ**: Kerberos認証、SSL/TLS設定