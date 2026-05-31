# ── GitHub ────────────────────────────────────────────────────────────────────

# Used to scope the OIDC trust conditions on the IAM roles so only this
# repository's GitHub Actions workflows can assume them.
variable "github_repo" {
  type        = string
  description = "GitHub repository in org/repo format (e.g. cpiazza01/isolated-rds-instances-with-data-examples)"
}

# ── Naming ────────────────────────────────────────────────────────────────────

# Applied to all IAM resource names (roles and policies) created by this module.
variable "name_prefix" {
  type        = string
  description = "Prefix applied to all IAM resource names"
}

# ── S3 State Buckets ──────────────────────────────────────────────────────────

# S3 bucket names are globally unique — choose a prefix that won't collide with
# other accounts (e.g. include your account alias or username).
# S3 buckets:      {prefix}-{env}-{region}
# DynamoDB tables: {prefix}-lock-{env}-{region}
variable "state_bucket_prefix" {
  type        = string
  description = "Prefix for all S3 state bucket names. Buckets are named {prefix}-{env}-{region}. Must be globally unique across all AWS accounts."
}

# Determines which S3 buckets are created. Add a new entry here when adding a
# new environment directory under module/*/environments/.
variable "state_environments" {
  type        = list(string)
  description = "Environments to create S3 state buckets for. Must match the env directory names under module/*/environments/."
  default     = ["dev", "test", "prod"]
}

# Determines which S3 buckets are created per environment. Add a new entry here
# when adding a new region directory, and update the matching region.hcl files.
variable "state_regions" {
  type        = list(string)
  description = "Regions to create S3 state buckets for. Must match the region directory names under each environment."
  default     = ["us-east-1"]
}
