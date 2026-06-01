# Inputs shared across all environments and regions for this module.
# Every key must correspond to a declared variable in variables.tf.

locals {
  vpc_cidr = "10.101.0.0/16"

  db_name        = "appdb"
  db_username    = "dbadmin"
  db_storage_gb  = 20
  enable_bastion = true

  # EC2 key pair name used to SSH to the bastion host.
  # Create one: aws ec2 create-key-pair --key-name rds-testing-key --region us-east-1 \
  #   --query KeyMaterial --output text > ~/.ssh/rds-testing-key.pem && chmod 400 ~/.ssh/rds-testing-key.pem
  bastion_ssh_key_name = "rds-testing-key"

  # ARN of the permission boundary created by bootstrap. Required so the
  # GitHub Actions IAMCreateRoleWithBoundary condition allows seeder Lambda
  # role creation. The account ID (321923606518) is specific to this deployment —
  # replace with your own after running bootstrap:
  #   terraform output lambda_boundary_arn
  # (run in module/bootstrap/environments/account/global/).
  lambda_permission_boundary_arn = "arn:aws:iam::321923606518:policy/isolated-rds-examples-lambda-boundary"
}
