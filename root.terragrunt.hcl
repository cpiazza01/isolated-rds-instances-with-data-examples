# Root Terragrunt configuration — inherited by every leaf terragrunt.hcl via
# find_in_parent_folders("root.terragrunt.hcl"). Handles remote state and
# AWS provider generation so neither needs to be repeated per-deployment.
#
# The S3 state bucket, DynamoDB lock table, and AWS region are read from the
# region.hcl that sits alongside the leaf terragrunt.hcl. find_in_parent_folders
# only searches parent directories (never the current directory), so we use
# get_original_terragrunt_dir() to reference the leaf's own directory directly.

locals {
  region_config   = read_terragrunt_config("${get_original_terragrunt_dir()}/region.hcl")
  aws_region      = local.region_config.locals.aws_region
  tf_state_bucket = local.region_config.locals.tf_state_bucket
  tf_lock_table   = local.region_config.locals.tf_lock_table
}

# ---------------------------------------------------------------------------
# Remote state
# One state file per deployment path. Bucket, lock table, and region come from
# region.hcl so each env/region combination uses its own isolated state bucket
# and DynamoDB lock table to prevent concurrent applies from corrupting state.
# ---------------------------------------------------------------------------
remote_state {
  backend = "s3"
  config = {
    bucket         = local.tf_state_bucket
    # path_relative_to_include() returns the caller's directory relative to this
    # file, producing a unique S3 key per deployment (e.g.
    # "isolated-rds-instances-with-data-examples/module/postgres/environments/dev/us-east-1/terraform.tfstate").
    key            = "isolated-rds-instances-with-data-examples/${path_relative_to_include()}/terraform.tfstate"
    region         = local.aws_region
    dynamodb_table = local.tf_lock_table

    # Bootstrap owns all bucket configuration (versioning, encryption, public
    # access blocking, root denial, TLS enforcement). This stops Terragrunt
    # from attempting any bucket updates at init time, which would require
    # s3:PutBucketPolicy and other permissions the GitHub Actions role doesn't need.
    disable_bucket_update = true
  }
  generate = {
    path      = "backend.tf"
    # overwrite_terragrunt: overwrite the file only if Terragrunt generated it.
    # Errors if a manually-written backend.tf already exists, preventing accidental overwrites.
    if_exists = "overwrite_terragrunt"
  }
}

# ---------------------------------------------------------------------------
# Provider
# Generated into .terragrunt-cache/ so no provider block is needed in the
# module/ directories themselves.
# ---------------------------------------------------------------------------
generate "provider" {
  path      = "provider.tf"
  # See remote_state.generate.if_exists above for why overwrite_terragrunt is used.
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "aws" {
      region = "${local.aws_region}"
    }
  EOF
}
