# Bootstrap inputs — account-level values shared across all deployments.

locals {
  # GitHub repository in org/repo format.
  github_repo = "cpiazza01/isolated-rds-instances-with-data-examples"

  # Prefix for IAM resource names, S3 state buckets, and DynamoDB lock tables.
  # S3 buckets:      {state_bucket_prefix}-{env}-{region}
  # DynamoDB tables: {state_bucket_prefix}-lock-{env}-{region}
  # Both must match the tf_state_bucket and tf_lock_table values in each module's region.hcl.
  name_prefix         = "isolated-rds-examples"
  state_bucket_prefix = "cpiazza01-tf-state"

  # Environments and regions to create state buckets for.
  # Add a new entry here and a matching region.hcl when expanding to new regions.
  state_environments = ["dev", "test", "prod"]
  state_regions      = ["us-east-1"]
}
