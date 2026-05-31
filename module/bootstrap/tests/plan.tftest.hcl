# Plan-only tests using mock providers — no AWS credentials required.
# Validates that the bootstrap module produces a valid plan for typical configurations.

mock_provider "aws" {}

# Baseline values matching the shape of common.hcl.
variables {
  github_repo         = "myorg/myrepo"
  name_prefix         = "test-bootstrap"
  state_bucket_prefix = "test-tfstate"
  state_environments  = ["dev", "test", "prod"]
  state_regions       = ["us-east-1"]
}

run "default_config" {
  command = plan

  assert {
    condition     = length(aws_s3_bucket.state) == 3
    error_message = "Expected one S3 bucket per env/region (3 environments × 1 region = 3)"
  }

  assert {
    condition     = length(aws_dynamodb_table.state_lock) == 3
    error_message = "Expected one DynamoDB lock table per env/region (3 environments × 1 region = 3)"
  }

  assert {
    condition     = length(aws_iam_role.github_actions) == 3
    error_message = "Expected three GitHub Actions IAM roles (dev, test, prod)"
  }
}

run "multi_region" {
  command = plan

  variables {
    state_regions = ["us-east-1", "us-west-2"]
  }

  assert {
    condition     = length(aws_s3_bucket.state) == 6
    error_message = "Expected one S3 bucket per env/region (3 environments × 2 regions = 6)"
  }

  assert {
    condition     = length(aws_dynamodb_table.state_lock) == 6
    error_message = "Expected one DynamoDB lock table per env/region (3 environments × 2 regions = 6)"
  }

  assert {
    condition     = length(aws_iam_role.github_actions) == 3
    error_message = "IAM roles are not regional — adding regions must not create additional roles"
  }
}
