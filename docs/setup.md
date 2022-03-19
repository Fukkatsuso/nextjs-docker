# setup

## Next.js + TypeScript + Tailwind CSS

### create-next-app

```bash
docker run -v `pwd`:/app -w /app --rm node:16-slim npx create-next-app . --typescript
```

このとき Dockerfile, README.md が既にカレントディレクトリに含まれている場合，一時的に消去することを要求された

動作確認として，以下を実行して <http://localhost:3000> にアクセスする

```bash
docker run -v `pwd`:/app -w /app --rm -p 3000:3000 -it node:16-slim npm run dev
```

tsconfig.jsonに以下の設定を追加する

```json
{
  "compilerOptions": {
    "baseUrl": ".",
  }
}
```

### Tailwind CSS

[Install Tailwind CSS with Next.js](https://tailwindcss.com/docs/guides/nextjs) を参考にして導入する

```bash
docker run -v `pwd`:/app -w /app --rm -p 3000:3000 -it node:16-slim bash
/app# npm install -D tailwindcss postcss autoprefixer
/app# npx tailwindcss init -p
```

## Docker

Dockerfile, docker-compose.yml を作成して `docker-compose up`

node_modules はホストと共有しないことにするが，エディタから参照できるようにするには

```bash
docker run -v `pwd`:/app -w /app --rm -it node:16-slim npm ci
```

でインストールすると良い

- [node_modulesのマウントに関する注意](https://zenn.dev/foolishell/articles/3d327557af3554)

## GCP

1. プロジェクトの作成

```bash
export PROJECT_ID=nextjs-docker-XXXXXX
gcloud projects create ${PROJECT_ID} --name nextjs-docker
gcloud config set project ${PROJECT_ID}
```

2. APIと課金の有効化

```bash
# API
gcloud services enable cloudresourcemanager.googleapis.com

# billing
gcloud alpha billing accounts list # 請求先アカウントのIDを控えておく
gcloud alpha billing projects link ${PROJECT_ID} --billing-account <ACCOUNT_ID>
gcloud services enable cloudbilling.googleapis.com
gcloud services enable cloudbuild.googleapis.com
```

3. サービスアカウントとサービスアカウントキーの作成，権限付与

```bash
# account
export SA_NAME=nextjs-run
gcloud iam service-accounts create ${SA_NAME} \
  --description="used by Terraform, GitHub Actions" \
  --display-name="${SA_NAME}"
gcloud iam service-accounts list # サービスアカウントが作られたことを確認

# key
export IAM_ACCOUNT=${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com
gcloud iam service-accounts keys create ~/${PROJECT_ID}/${SA_NAME}/key.json \
  --iam-account ${IAM_ACCOUNT}
```

`key.json` がサービスアカウントキーとなる

```bash
# role
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${IAM_ACCOUNT}" \
  --role="roles/editor"
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${IAM_ACCOUNT}" \
  --role="roles/run.admin" # allUsersへのアクセス権付与のためにadmin権限が必要
```

4. Terraformのバックエンド用のGCSバケットを作成

```bash
export REGION=asia-northeast1
export BACKEND_BUCKET=nextjs-docker-tfstate
gsutil mb -l ${REGION} gs://${BACKEND_BUCKET}
```

## Terraform

1. tfstate管理のためのGCSバックエンドを用意
  - 案1: backend用バケット作成のとき1回だけ実行するtfファイルを作成
    - GCSのAPI有効化，サービスアカウントへGCS編集権限付与 => TerraformでGCSを操作できるようになるはず
    - ローカルから `terraform apply` （CD構築までは不要．ローカルからgcloudでログインする必要アリ）
  - 案2: **gcloudコマンドでバケット作成とサービスアカウントへの権限付与までやってしまう**
    - tfstateは高々1プロジェクト1ファイルとかなので，コマンドさえメモしておけば別のプロジェクトでもすぐ再利用可能（できれば全部コード化したいが）
    - バケット作成, GCS関連の権限付与
  - サービスアカウントのGCS権限は， `roles/editor` さえあれば追加の権限付与は不要
2. GCSバックエンドを使う設定をmain.tfに書く
  - <https://www.terraform.io/language/settings/backends/gcs>
3. main.tfでは，Cloud RunのAPI有効化及び全ユーザへのアクセス権付与も書く

- [Terraform Cloud Run Module](https://github.com/GoogleCloudPlatform/terraform-google-cloud-run)
- [Cloud Run example](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_run_service)
- [Deploying to Google Cloud Run with Terraform](https://ruanmartinelli.com/posts/terraform-cloud-run)

## GitHub Actions

- pull request => fmt, init, gcp-auth, validate, plan
- push main => init, gcp-auth, plan, docker-build, docker-push, apply
- `terraform plan` の実行にはGCP認証が必要

- GitHub Secrets の設定
  - GCP_PROJECT: GCPプロジェクトID
  - GOOGLE_CREDENTIALS: サービスアカウントのキーの中身をコピペ

- hashicorp/setup-terraform を使用
- [Automate Terraform with GitHub Actions](https://learn.hashicorp.com/tutorials/terraform/github-actions)
- [Automating Terraform Deployment to Google Cloud with GitHub Actions](https://medium.com/interleap/automating-terraform-deployment-to-google-cloud-with-github-actions-17516c4fb2e5)
- [GitHub Actions でプルリクのマージでワークフローを実行する](https://qiita.com/okazy/items/7ab46f2c20ec341a2836)
- [Github ActionsとTerraformを利用してGCPのIaCに取り組んでみる。](https://qiita.com/sand_bash/items/a3459c9a62d1c792ac2f)
