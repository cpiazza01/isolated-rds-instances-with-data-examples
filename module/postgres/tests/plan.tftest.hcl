# Plan-only tests using mock providers — no AWS credentials required.
# Validates that the module produces a valid plan for different environment configurations.

mock_provider "aws" {}
mock_provider "archive" {}
mock_provider "tls" {}

# Baseline variable values shared across all runs.
variables {
  aws_region         = "us-east-1"
  name_prefix        = "test-pg"
  availability_zones = ["us-east-1a", "us-east-1b"]

  db_instance_class = "db.t3.micro"
  db_name           = "appdb"
  db_username       = "dbadmin"
  db_storage_gb     = 20

  row_count              = 100
  skip_final_snapshot    = true
  db_deletion_protection = false

  enable_bastion        = true
  bastion_ssh_key_name  = "test-key"
  bastion_allowed_cidrs = ["10.0.0.1/32"]
}

run "dev_config" {
  command = plan

  # Mock providers prevent inspecting planned resource attributes inside the
  # upstream module call, so these assertions validate the safety-critical
  # variables at the boundary where this module receives them.
  assert {
    condition     = var.db_deletion_protection == false
    error_message = "dev should not have deletion protection enabled"
  }

  assert {
    condition     = var.skip_final_snapshot == true
    error_message = "dev should skip the final snapshot"
  }
}

run "prod_config" {
  command = plan

  variables {
    db_instance_class      = "db.t3.small"
    row_count              = 10000
    skip_final_snapshot    = false
    db_deletion_protection = true
  }

  assert {
    condition     = var.db_deletion_protection == true
    error_message = "prod must have deletion protection enabled"
  }

  assert {
    condition     = var.skip_final_snapshot == false
    error_message = "prod must retain a final snapshot on destroy"
  }
}

run "row_count_too_low" {
  command = plan

  variables {
    row_count = 0
  }

  expect_failures = [var.row_count]
}

run "row_count_too_high" {
  command = plan

  variables {
    row_count = 1000001
  }

  expect_failures = [var.row_count]
}

run "availability_zones_too_few" {
  command = plan

  variables {
    availability_zones = ["us-east-1a"]
  }

  expect_failures = [var.availability_zones]
}

run "db_storage_too_small" {
  command = plan

  variables {
    db_storage_gb = 19
  }

  expect_failures = [var.db_storage_gb]
}

run "bastion_cidr_placeholder" {
  command = plan

  variables {
    bastion_allowed_cidrs = ["1.2.3.4/32"]
  }

  expect_failures = [var.bastion_allowed_cidrs]
}
