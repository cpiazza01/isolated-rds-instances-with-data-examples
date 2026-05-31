output "lock_table_names" {
  description = "DynamoDB lock table names by env/region — already reflected in each module's region.hcl as tf_lock_table"
  value       = { for k, v in aws_dynamodb_table.state_lock : k => v.name }
}

output "state_bucket_names" {
  description = "S3 state bucket names created — already reflected in each module's region.hcl"
  value       = { for k, v in aws_s3_bucket.state : k => v.bucket }
}

output "lambda_boundary_arn" {
  description = "Permission boundary ARN — pass this to any module that creates IAM roles"
  value       = aws_iam_policy.lambda_boundary.arn
}

output "oidc_provider_arn" {
  description = "GitHub OIDC provider ARN (pre-existing, not managed by this module)"
  value       = data.aws_iam_openid_connect_provider.github.arn
}

output "dev_role_arn" {
  description = "Set as AWS_ROLE_ARN in: repo-level secrets AND the 'dev' GitHub Environment secret"
  value       = aws_iam_role.github_actions["dev"].arn
}

output "test_role_arn" {
  description = "Set as AWS_ROLE_ARN in: the 'test' GitHub Environment secret"
  value       = aws_iam_role.github_actions["test"].arn
}

output "prod_role_arn" {
  description = "Set as AWS_ROLE_ARN in: the 'prod' GitHub Environment secret"
  value       = aws_iam_role.github_actions["prod"].arn
}

output "next_steps" {
  description = "What to do after applying bootstrap"
  value       = <<-EOT
    1. Set repo-level GitHub secret (used by plan job on PRs):
         AWS_ROLE_ARN = ${aws_iam_role.github_actions["dev"].arn}

    2. Set per-environment GitHub secrets (Settings → Environments):
         dev  → AWS_ROLE_ARN = ${aws_iam_role.github_actions["dev"].arn}
         test → AWS_ROLE_ARN = ${aws_iam_role.github_actions["test"].arn}
         prod → AWS_ROLE_ARN = ${aws_iam_role.github_actions["prod"].arn}
  EOT
}
