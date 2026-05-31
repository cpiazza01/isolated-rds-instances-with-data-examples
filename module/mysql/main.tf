# MySQL root module — invoked by Terragrunt from environments/<env>/<region>/.
# All inputs are provided via Terragrunt; do not run terraform directly here.

# Provisions a private MySQL 8.0.35 RDS instance inside its own VPC, seeded with
# dummy data via a Lambda function, and optionally accessible through a bastion SSH tunnel.
module "isolated_rds" {
  source = "github.com/cpiazza01/isolated-rds-instances-with-data?ref=main"

  aws_region         = var.aws_region
  name_prefix        = var.name_prefix
  availability_zones = var.availability_zones

  db_engine         = "mysql"
  db_engine_version = "8.0.35"
  db_instance_class = var.db_instance_class
  db_name           = var.db_name
  db_username       = var.db_username
  db_storage_gb     = var.db_storage_gb

  row_count = var.row_count

  skip_final_snapshot    = var.skip_final_snapshot
  db_deletion_protection = var.db_deletion_protection

  enable_bastion        = var.enable_bastion
  bastion_ssh_key_name  = var.bastion_ssh_key_name
  bastion_allowed_cidrs = var.bastion_allowed_cidrs
}