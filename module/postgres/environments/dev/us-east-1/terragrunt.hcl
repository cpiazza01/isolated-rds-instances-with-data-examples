include "root" {
  path = find_in_parent_folders("root.terragrunt.hcl")
}

locals {
  common = read_terragrunt_config(find_in_parent_folders("common.hcl"))
  env    = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  region = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  # Derive the environment name (dev/test/prod) from the directory path.
  environment = basename(dirname(get_terragrunt_dir()))
}

terraform {
  # Relative path from this file up to the module root (module/postgres/).
  source = "../../../"
}

inputs = merge(
  local.common.locals,
  local.env.locals,
  local.region.locals,
  {
    name_prefix = "quickstart-pg-${local.environment}"
  }
)
