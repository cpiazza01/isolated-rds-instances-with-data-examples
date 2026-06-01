# PostgreSQL + Client VPN root module — invoked by Terragrunt from environments/<env>/<region>/.
# All inputs are provided via Terragrunt; do not run terraform directly here.

# Provisions a private PostgreSQL 16 RDS instance inside its own VPC, seeded with
# dummy data via a Lambda function, and accessible via AWS Client VPN — no bastion host.
module "isolated_rds" {
  source = "github.com/cpiazza01/isolated-rds-instances-with-data?ref=v0.1.1"

  aws_region         = var.aws_region
  name_prefix        = var.name_prefix
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones

  db_engine         = "postgres"
  db_engine_version = "16"
  db_instance_class = var.db_instance_class
  db_name           = var.db_name
  db_username       = var.db_username
  db_storage_gb     = var.db_storage_gb

  lambda_permission_boundary_arn = var.lambda_permission_boundary_arn

  row_count = var.row_count

  skip_final_snapshot    = var.skip_final_snapshot
  db_deletion_protection = var.db_deletion_protection

  # Bastion is intentionally disabled — use the Client VPN endpoint instead.
  enable_bastion = false

  enable_client_vpn                    = true
  client_vpn_cidr                      = var.client_vpn_cidr
  client_vpn_create_certificates       = var.client_vpn_create_certificates
  client_vpn_server_cert_arn           = var.client_vpn_server_cert_arn
  client_vpn_root_cert_arn             = var.client_vpn_root_cert_arn
  client_vpn_client_names              = var.client_vpn_client_names
  client_vpn_enable_connection_logging = var.client_vpn_enable_connection_logging
  client_vpn_split_tunnel              = var.client_vpn_split_tunnel
}
