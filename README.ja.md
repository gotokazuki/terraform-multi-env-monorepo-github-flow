# Terraform Multi-Environment Monorepo with GitHub Flow

[![Read in English](https://img.shields.io/badge/Language-English-green.svg)](README.md)

GitHub Flow を採用した、本番運用可能な Terraform マルチ環境モノレポの構成例です。

単一のモノレポ内で複数の環境（`dev`、`stg`、`prod`）を安全に管理し、Git タグを活用してモジュールのバージョン管理を行う設計を提示しています。Docker Compose 経由で [Floci](https://github.com/floci-io/floci)（AWS エミュレータ）を利用することにより、実際の AWS アカウントを用意することなく完全ローカル環境で検証が可能です。

## 💡 主な特徴

- **マルチ環境モノレポ**: 環境ごと（`environments/dev`、`stg`、`prod`）にディレクトリを分離し、変更の影響範囲を最小限に限定します。
- **Git タグによるモジュールバージョン管理**: 上位環境（`stg`、`prod`）では Git タグ（`?ref=vX.Y.Z`）を用いてモジュールを固定参照し、共通モジュール更新時の予期せぬ破壊的変更を防止します。
- **GitHub Flow 準拠**: メインブランチを中心とした短命なトピックブランチ運用、プルリクエスト、および Git リリースタグによるデプロイ管理に最適化されています。

## 📁 ディレクトリ構成

```shell
.
├── compose.yaml        # Floci ローカル AWS エミュレータ設定
├── environments/
│   ├── dev/            # 開発環境（ローカル相対パスでモジュール参照）
│   │   ├── main.tf
│   │   ├── providers.tf
│   │   └── variables.tf
│   ├── stg/            # ステージング環境（Git タグ固定でモジュール参照）
│   │   ├── main.tf
│   │   ├── providers.tf
│   │   └── variables.tf
│   └── prod/           # 本番環境（Git タグ固定でモジュール参照）
│       ├── main.tf
│       ├── providers.tf
│       └── variables.tf
└── modules/            # 再利用可能な共通モジュール
    ├── storage/        # S3 バケットモジュール
    │   ├── main.tf
    │   ├── outputs.tf
    │   └── variables.tf
    └── database/       # DynamoDB テーブルモジュール
        ├── main.tf
        ├── outputs.tf
        └── variables.tf
```

## 🛠 前提条件

- [Terraform](https://www.terraform.io/) >= 1.0.0
- Docker および Docker Compose
- AWS CLI（ローカル検証リソース確認用）

## 🚀 クイックスタート

1. Floci（ローカル AWS エミュレータ）の起動:

   ```bash
   docker compose up -d
   ```

1. 開発環境（`dev`）へのデプロイ:

   ```bash
   cd environments/dev
   terraform init
   terraform apply
   ```

1. 作成リソースの確認:

   Floci はポート `4566` で動作します。AWS CLI でダミーの認証情報を付与してリソースの存在を確認します。

   ```bash
   AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test aws --endpoint-url=http://localhost:4566 s3 ls
   AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test aws --endpoint-url=http://localhost:4566 dynamodb list-tables --region ap-northeast-1
   ```

1. 環境の破棄:

   ローカルのステートファイルと Floci 上の実リソースとの整合性を保つため、破棄手順を実行してからコンテナを停止します。

   ```bash
   terraform destroy
   cd ../..
   docker compose down
   ```

## 🔄 開発およびリリースフロー

### 1. 開発環境でのローカル検証（`dev`）

`environments/dev/` では、共通モジュールをローカル相対パス（`../../modules/...`）で参照します。これにより、`modules/` 配下の変更内容をコミットやタグ打ちなしで即座に `dev` 環境で動作検証できます。

### 2. モジュールのバージョンリリース

`dev` 環境での検証完了後、プルリクエスト経由で `main` ブランチへマージを行います。その後、セマンティックバージョニングに従った Git リリースタグを作成してリモートへプッシュします。

```bash
git tag v1.1.0
git push origin v1.1.0
```

### 3. 段階的な環境昇格（`stg` -> `prod`）

上位環境では、Git リポジトリ URL とリリースタグを指定してモジュールを参照します。

```hcl
module "storage" {
  # 独自リポジトリやフォーク先で利用する場合は、リポジトリ URL を適宜書き換えてください
  source      = "git::https://github.com/gotokazuki/terraform-multi-env-monorepo-github-flow.git//modules/storage?ref=v1.1.0"
  bucket_name = "my-app-stg-storage"
}

module "database" {
  source     = "git::https://github.com/gotokazuki/terraform-multi-env-monorepo-github-flow.git//modules/database?ref=v1.1.0"
  table_name = "my-app-stg-db"
}
```

1. トピックブランチを作成し、`environments/stg/main.tf` のタグ参照を更新します。
1. `environments/stg` 配下で `terraform init -upgrade` を実行して `.terraform/modules` のキャッシュを更新し、新しいバージョンのモジュールを取得した上で `terraform apply` を実行して検証を行います。
1. プルリクエストを作成して `main` へマージ後、同様の手順で `environments/prod/main.tf` を昇格させます。

## 🏭 本番 AWS 環境への移行に向けた考慮事項

本リポジトリは Floci によるローカル検証を目的とした設定になっています。実際の AWS 本番運用に移行する際は、以下の設定変更を行います。

- **リモートステート管理**: 各環境の `providers.tf` にリモートバックエンド設定を追加し、チーム間での安全な状態共有と排他制御（ステートロック）を有効化します。
- **エンドポイント設定の解除**: `providers.tf` 内の `endpoints` ブロック（`http://localhost:4566`）および `skip_*` などのエミュレータ用フラグを削除し、実 AWS エンドポイントへ接続します。
- **認証の移行**: ダミーの静的アクセスキー設定を削除し、AWS IAM ロールや GitHub Actions OIDC などのセキュアな一時クレデンシャル認証に移行します。
