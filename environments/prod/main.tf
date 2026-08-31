# Refers to tagged release modules
module "storage" {
  source      = "git::https://github.com/gotokazuki/terraform-multi-env-monorepo-github-flow.git//modules/storage?ref=v1.0.0"
  bucket_name = "my-app-prod-storage"
}

module "database" {
  source     = "git::https://github.com/gotokazuki/terraform-multi-env-monorepo-github-flow.git//modules/database?ref=v1.0.0"
  table_name = "my-app-prod-db"
}
