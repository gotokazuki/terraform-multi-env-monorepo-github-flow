# Terraform Multi-Environment Monorepo with GitHub Flow

[![Read in Japanese](https://img.shields.io/badge/Language-日本語-blue.svg)](README.ja.md)

A production-ready example of a multi-environment Terraform monorepo structure using GitHub Flow.

This repository demonstrates how to manage multiple environments (`dev`, `stg`, `prod`) in a single monorepo, version reusable modules using Git tags, and test the entire infrastructure locally without an AWS account using [Floci](https://github.com/floci-io/floci) via Docker Compose.

## 💡 Key Features

- **Multi-Environment Monorepo**: Directory-level separation (`environments/dev`, `stg`, `prod`) to keep the blast radius isolated.
- **Module Versioning via Git Tags**: Upper environments (`stg` and `prod`) reference tagged releases (`?ref=vX.Y.Z`) to prevent unexpected disruptions from shared module updates.
- **GitHub Flow Compliant**: Built for trunk-based development with short-lived feature branches, pull requests, and Git release tags.

## 📁 Directory Structure

```shell
.
├── compose.yaml        # Floci local AWS emulator configuration
├── environments/
│   ├── dev/            # Development (Local relative module paths)
│   │   ├── main.tf
│   │   ├── providers.tf
│   │   └── variables.tf
│   ├── stg/            # Staging (Git tag pinned modules)
│   │   ├── main.tf
│   │   ├── providers.tf
│   │   └── variables.tf
│   └── prod/           # Production (Git tag pinned modules)
│       ├── main.tf
│       ├── providers.tf
│       └── variables.tf
└── modules/            # Reusable core modules
    ├── storage/        # S3 bucket module
    │   ├── main.tf
    │   ├── outputs.tf
    │   └── variables.tf
    └── database/       # DynamoDB table module
        ├── main.tf
        ├── outputs.tf
        └── variables.tf
```

## 🛠 Prerequisites

- [Terraform](https://www.terraform.io/) >= 1.0.0
- Docker & Docker Compose
- AWS CLI (for local resource verification)

## 🚀 Quick Start (Local Testing with Floci)

1. Start Floci (Local AWS Emulator):

   ```bash
   docker compose up -d
   ```

1. Deploy to Development Environment (`dev`):

   ```bash
   cd environments/dev
   terraform init
   terraform apply
   ```

1. Verify Created Resources:

   Floci runs on port `4566`. Use the AWS CLI with dummy credentials to inspect resources:

   ```bash
   AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test aws --endpoint-url=http://localhost:4566 s3 ls
   AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test aws --endpoint-url=http://localhost:4566 dynamodb list-tables --region ap-northeast-1
   ```

1. Clean Up:

   To maintain state consistency with local files, destroy the resources before shutting down the container:

   ```bash
   terraform destroy
   cd ../..
   docker compose down
   ```

## 🔄 Development & Release Workflow (GitHub Flow)

### 1. Local Development (`dev`)

In `environments/dev/`, modules are referenced using local relative paths (`../../modules/...`). Code changes in `modules/` are immediately testable in `dev` without committing or tagging.

### 2. Module Versioning & Release

When module updates are verified in `dev` and merged into `main` via Pull Request, create a new semantic version tag and push it to the remote repository:

```bash
git tag v1.1.0
git push origin v1.1.0
```

### 3. Stepwise Promotion (`stg` -> `prod`)

Upper environments reference modules via Git repository URLs with release tags:

```hcl
module "storage" {
  # Replace the repository URL if using a fork or your own repository
  source      = "git::https://github.com/gotokazuki/terraform-multi-env-monorepo-github-flow.git//modules/storage?ref=v1.1.0"
  bucket_name = "my-app-stg-storage"
}

module "database" {
  source     = "git::https://github.com/gotokazuki/terraform-multi-env-monorepo-github-flow.git//modules/database?ref=v1.1.0"
  table_name = "my-app-stg-db"
}
```

1. Create a branch and update the tag in `environments/stg/main.tf`.
1. Run `terraform init -upgrade` in `stg` to update `.terraform/modules` cache and download the new tag, then run `terraform apply` to verify.
1. Open a Pull Request, merge into `main`, and repeat the process for `environments/prod/main.tf`.

## 🏭 Production Readiness Considerations

This repository is configured for local simulation with Floci. When transitioning to real AWS production environments, consider the following:

- **Remote State Backend**: Configure a remote backend in each environment's `providers.tf` for secure team collaboration and state locking.
- **Remove Local Endpoints**: Remove the `endpoints` block (`http://localhost:4566`) and `skip_*` flags from `providers.tf` to route directly to AWS.
- **Authentication**: Replace dummy credentials with IAM roles, AWS SSO, or GitHub Actions OIDC for short-lived credentials.
