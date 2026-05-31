# Inputs shared across all environments and regions for this module.
# Every key must correspond to a declared variable in variables.tf.

locals {
  db_name        = "appdb"
  db_username    = "dbadmin"
  db_storage_gb  = 20
  enable_bastion = true

  # EC2 key pair name used to SSH to the bastion host.
  # Create one: aws ec2 create-key-pair --key-name my-rds-testing-key --region us-east-1 \
  #   --query KeyMaterial --output text > ~/.ssh/my-rds-testing-key.pem && chmod 400 ~/.ssh/my-rds-testing-key.pem
  bastion_ssh_key_name = "my-rds-testing-key"
}
