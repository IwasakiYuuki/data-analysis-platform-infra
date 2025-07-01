# 開発環境の設定検討メモ

開発環境の設定を考える。
まずは項目を分けて考えてみようと思う。

1. ノード数
2. リソース
3. ネットワーク
4. 永続ボリューム
5. 開発体験
6. 本番環境との一貫性

### 1. ノード数

ノード数はHadoopクラスタの最小構成であるNameNode1台、DataNode3台にしようと思う。
KubernetesのでコントロールプレーンにNameNodeを乗せると考えて、ワーカを3台にする。

**更新後の決定事項**：
- Control-plane: NameNode, ResourceManager, JupyterHub, Airflow を配置
- Worker 3台: 各々に1つのDataNodeを配置（1Node=1DataNode）
- control-planeのtaintを削除してPod配置可能にする

### 2. リソース

リソースはコントロールプレーンを2GB, 2core, 10GBのSSD、ワーカをそれぞれ2GB, 1core, 10GBのSSDにする。
開発用なのでリソースは少なめにする。

**更新後の決定事項**：
- 現在のPCリソース: メモリ15GB、CPU 8コア、ディスク148GB空き
- Control-plane: メモリ4GB、CPU 2コア（複数コンポーネント配置のため増量）
- Worker: メモリ1GB、CPU 1コア×3台
- Docker全体制限: Memory 8GB、CPU 6core推奨

### 3. ネットワーク

さてどうするか、Kubernetesのネットワークについてあまり知らないんだよね。
ネットワークは今の所いじるところがあまりなさそうなので、そのままにしておこう。

**学習した内容**：
- Kubernetesネットワークの4つのレイヤー: Pod間通信、Service、Ingress、DNS
- CNI（kindnet）がPod間通信を管理、各Podにvethペア作成
- 固定ホスト名の実現方法: StatefulSet + Headless Service vs HostNetwork
- 外部アクセス: extraPortMappingsでブラウザアクセス対応
- 開発環境ではkindのデフォルト設定で十分

### 4. 永続ボリューム

ここはリソースのところでやっていたので特になし

**追加検討事項**：
- データローカリティ: Local PV vs HostPath vs 通常のPVC
- テスト用途なので各ノード10GB程度で十分
- 本番環境では永続化方式を要検討

### 5. 開発体験

Skaffoldとか言うのがあるらしい。

**Skaffoldの詳細**：
- ファイル変更 → 自動検知 → ビルド → デプロイ → ログ表示
- Kind対応: `push: false`でローカル完結
- `skaffold dev`で開発モード、統合ログ表示
- 従来の手動ワークフロー（docker build → kind load → kubectl apply）を自動化

### 6. 本番環境との一貫性

ノード数を本番環境と同じにする。
あとは周辺の環境（Kerberosなど）なども考える必要はあるかな。
ただこれはKubernetesの範囲内ではない想定なので、docker composeとかで対応するかな。

**一貫性の観点**：
- アーキテクチャ一貫性: 同じノード数・役割分担
- 設定一貫性: Hadoop設定ファイルの共通化
- デプロイ方法一貫性: kubectl apply方式の統一
- セキュリティ一貫性: Kerberos認証、SSL/TLS設定

## 重要な学び

### システム設計の考え方
- 要件定義から設定への落とし込み: 形式的手続き + 現実的アプローチ
- 設定の優先順位: 必須 → 本番必須 → パフォーマンス → セキュリティ・運用
- 深い理解の重要性: QuickStart方式の限界、「なぜ」を3回問う

### Kind設定のトラブルシューティング
- **featureGates問題**: `EphemeralContainers: true`でkubelet起動失敗
- **原因**: Kubernetes 1.25+では既にデフォルト有効、バージョン互換性問題
- **解決**: 不要なfeatureGatesをコメントアウト

## 次のステップ
1. Kind環境でのHadoopマニフェスト作成
2. StatefulSet vs Deployment選択
3. 固定ホスト名実装方法の決定
4. 開発ワークフローの自動化（Skaffold導入）
