include "root" {
  path = find_in_parent_folders("root.terragrunt.hcl")
}

locals {
  common = read_terragrunt_config(find_in_parent_folders("common.hcl"))
  env    = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  # region.hcl is in the same directory as this file, not a parent, so we
  # reference it directly — find_in_parent_folders only searches parent dirs.
  region = read_terragrunt_config("${get_terragrunt_dir()}/region.hcl")

  # Derives the environment name (dev/test/prod) from the directory path.
  environment = basename(dirname(get_terragrunt_dir()))
}

terraform {
  # Relative path from this file up to the module root (module/mysql/).
  source = "../../../"
}

inputs = merge(
  local.common.locals,
  local.env.locals,
  local.region.locals,
  {
    name_prefix = "quickstart-mysql-${local.environment}"
  }
)
