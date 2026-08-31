# Refers to local relative module path
module "storage" {
  source      = "../../modules/storage"
  bucket_name = "my-app-dev-storage"
}

module "database" {
  source     = "../../modules/database"
  table_name = "my-app-dev-db"
}
