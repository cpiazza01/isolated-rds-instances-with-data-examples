# Bootstrap is a one-time account-level setup. It does NOT include root.terragrunt.hcl
# because it creates the S3 buckets that root.terragrunt.hcl depends on.
# It uses local Terraform state — commit the generated terraform.tfstate to a
# secure location (or use a pre-existing S3 bucket as a manual -backend-config override).

locals {
  common = read_terragrunt_config(find_in_parent_folders("common.hcl"))
}

# Block accidental destroy — the IAM roles and policies created here are relied
# on by all CI/CD pipelines. The S3/DynamoDB resources have their own
# lifecycle { prevent_destroy = true } but the IAM roles do not, so this
# Terragrunt guard provides a single early-exit for the entire stack.
prevent_destroy = true

terraform {
  # Relative path from this file up to the module root (module/bootstrap/).
  source = "../../../"
}

# Local backend — bootstrap creates the S3 buckets, so it cannot use them for its own state.
generate "backend" {
  path      = "backend.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    terraform {
      backend "local" {}
    }
  EOF
}

# IAM and S3 are global AWS services — the provider region only determines which
# API endpoint is used, not where resources are created. us-east-1 is the standard
# choice and is hardcoded here since bootstrap doesn't deploy to a specific region.
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "aws" {
      region = "us-east-1"
    }
  EOF
}

inputs = {
  github_repo         = local.common.locals.github_repo
  name_prefix         = local.common.locals.name_prefix
  state_bucket_prefix = local.common.locals.state_bucket_prefix
  state_environments  = local.common.locals.state_environments
  state_regions       = local.common.locals.state_regions
}
