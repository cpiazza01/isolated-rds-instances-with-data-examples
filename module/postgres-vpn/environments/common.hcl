# Inputs shared across all environments and regions for this module.
# Every key must correspond to a declared variable in variables.tf.

locals {
  db_name       = "appdb"
  db_username   = "dbadmin"
  db_storage_gb = 20

  # ARN of the permission boundary created by bootstrap. Required so the
  # GitHub Actions IAMCreateRoleWithBoundary condition allows seeder Lambda
  # role creation. Get the value from: terraform output lambda_boundary_arn
  # (run in module/bootstrap/environments/account/global/).
  lambda_permission_boundary_arn = "arn:aws:iam::321923606518:policy/isolated-rds-examples-lambda-boundary"

  # Client IP address pool — must not overlap with the VPC CIDR (10.0.0.0/16).
  client_vpn_cidr = "172.16.0.0/22"

  # One certificate/key pair is generated per name when create_certificates = true.
  # Add names to provision additional client profiles; remove and re-apply to revoke.
  client_vpn_client_names = ["developer"]

  # Route only VPC-bound traffic through the tunnel — keeps internet traffic local.
  client_vpn_split_tunnel = true

  # Enable in prod for an audit trail of who connected and when.
  client_vpn_enable_connection_logging = false
}
