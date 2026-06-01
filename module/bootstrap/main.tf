# Bootstrap module — run once to create the account-level foundation that all
# other modules depend on. Uses local Terraform state (see terragrunt.hcl).
#
# Creates:
#   - S3 state buckets (one per env/region combination, versioned + encrypted)
#   - GitHub OIDC provider (one per AWS account)
#   - Permission boundary that caps what seeder Lambda execution roles can do
#   - Three GitHub Actions IAM roles (dev / test / prod) with environment-specific
#     trust conditions and permission boundary enforcement on iam:CreateRole

# Used to reference the current account ID in IAM policy conditions.
data "aws_caller_identity" "current" {}

# ── S3 State Buckets ──────────────────────────────────────────────────────────
# One bucket per env/region combination. Bucket names follow the pattern:
#   ${var.state_bucket_prefix}-${env}-${region}
# This must match the tf_state_bucket values in each module's region.hcl.

# setproduct computes the cartesian product of environments × regions, yielding
# pairs like ["dev", "us-east-1"]. The for expression joins each pair into a
# single "dev-us-east-1" string used as the for_each key for S3 buckets and
# DynamoDB tables, and as the suffix in their resource names.
locals {
  state_bucket_keys = toset([
    for pair in setproduct(var.state_environments, var.state_regions) :
    "${pair[0]}-${pair[1]}"
  ])
}

# One bucket per env/region key — stores Terraform state for each environment.
resource "aws_s3_bucket" "state" {
  for_each = local.state_bucket_keys
  bucket   = "${var.state_bucket_prefix}-${each.key}"

  lifecycle {
    prevent_destroy = true
  }
}

# Enables versioning so state history is preserved and accidental overwrites are recoverable.
resource "aws_s3_bucket_versioning" "state" {
  for_each = aws_s3_bucket.state
  bucket   = each.value.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enforces KMS encryption at rest on every state bucket.
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  for_each = aws_s3_bucket.state
  bucket   = each.value.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

# Blocks all public access paths — state buckets must never be publicly readable.
resource "aws_s3_bucket_public_access_block" "state" {
  for_each = aws_s3_bucket.state
  bucket   = each.value.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enforces HTTPS-only access on state buckets. The public access block must
# exist first so block_public_policy is in place before any policy is attached.
resource "aws_s3_bucket_policy" "state_enforce_tls" {
  for_each   = aws_s3_bucket.state
  bucket     = each.value.id
  depends_on = [aws_s3_bucket_public_access_block.state]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyNonTLS"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          each.value.arn,
          "${each.value.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

# ── GitHub OIDC Provider ──────────────────────────────────────────────────────
# The OIDC provider is an account-level resource created once manually.
# Create it before running bootstrap:
#
#   AWS Console: IAM → Identity providers → Add provider
#     Provider type : OpenID Connect
#     Provider URL  : https://token.actions.githubusercontent.com
#     Audience      : sts.amazonaws.com
#
#   AWS CLI equivalent:
#     aws iam create-open-id-connect-provider \
#       --url https://token.actions.githubusercontent.com \
#       --client-id-list sts.amazonaws.com \
#       --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1

data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# ── Permission Boundary ───────────────────────────────────────────────────────
# Applied to the seeder Lambda execution role by the RDS modules.
# The GitHub Actions inline policy enforces attachment via an iam:PermissionsBoundary
# condition — Terraform is denied if it tries to create a role without this boundary.

resource "aws_iam_policy" "lambda_boundary" {
  name        = "${var.name_prefix}-lambda-boundary"
  description = "Permission boundary for Lambda execution roles created by Terraform"

  # Destroying this policy would break every subsequent module apply — the
  # IAMCreateRoleWithBoundary condition would deny role creation without it.
  lifecycle {
    prevent_destroy = true
  }

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "VPCAccess"
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeVpcs"
        ]
        Resource = "*"
      },
      {
        Sid      = "SecretsManagerRead"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

# ── DynamoDB State Lock Tables ────────────────────────────────────────────────
# One table per env/region combination, matching the S3 state bucket structure.
# Terraform acquires a lock item (keyed by the S3 state path) before every apply
# and releases it on completion, preventing concurrent applies from corrupting state.

resource "aws_dynamodb_table" "state_lock" {
  for_each     = local.state_bucket_keys
  name         = "${var.state_bucket_prefix}-lock-${each.key}"
  hash_key     = "LockID"
  billing_mode = "PAY_PER_REQUEST"

  attribute {
    name = "LockID"
    type = "S"
  }

  lifecycle {
    prevent_destroy = true
  }
}

# ── GitHub Actions Roles ──────────────────────────────────────────────────────
# One role per environment with environment-specific OIDC trust conditions:
#   dev  → any branch push or PR  (broad — workflow logic enforces the boundary)
#   test → push to main only
#   prod → GitHub "prod" environment only (pairs with required reviewers gate)
#
# After apply, copy the role ARNs from outputs and set them as AWS_ROLE_ARN in:
#   - repo-level variable (used by plan job on PRs) → use dev role ARN
#   - each GitHub Environment variable (Settings → Environments → dev / test / prod)

locals {
  roles = {
    dev = {
      condition_key = "StringLike"
      sub_value     = "repo:${var.github_repo}:*"
      description   = "Assumed by GitHub Actions on any branch push or PR"
    }
    test = {
      condition_key = "StringEquals"
      sub_value     = "repo:${var.github_repo}:ref:refs/heads/main"
      description   = "Assumed by GitHub Actions on push to main only"
    }
    prod = {
      condition_key = "StringEquals"
      sub_value     = "repo:${var.github_repo}:environment:prod"
      description   = "Assumed by GitHub Actions when the prod GitHub Environment is targeted"
    }
  }

  managed_policies = [
    "arn:aws:iam::aws:policy/AmazonVPCFullAccess",
    "arn:aws:iam::aws:policy/AmazonEC2FullAccess",
    "arn:aws:iam::aws:policy/AmazonRDSFullAccess",
    "arn:aws:iam::aws:policy/AWSLambda_FullAccess",
    "arn:aws:iam::aws:policy/SecretsManagerReadWrite",
    "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess",
  ]

  # Cartesian product of roles × managed policies, flattened into a map for for_each.
  # The key is "{role}--{policy-name}" (double-dash avoids collisions if a role or
  # policy name contains a single dash). split("/", arn)[1] extracts the short policy
  # name from the ARN — e.g. "AmazonVPCFullAccess" from the full ARN path.
  attachments = {
    for pair in setproduct(keys(local.roles), local.managed_policies) :
    "${pair[0]}--${split("/", pair[1])[1]}" => {
      role_key   = pair[0]
      policy_arn = pair[1]
    }
  }

  # S3 state buckets each role is allowed to READ. The dev role additionally reads
  # the test bucket because the plan job on PRs to main uses the repo-level (dev)
  # role ARN to plan against test state — cross-env read is needed, cross-env write is not.
  role_state_read_envs = {
    dev  = ["dev", "test"]
    test = ["test"]
    prod = ["prod"]
  }
}

# One role per environment — OIDC trust conditions differ per role (see locals.roles above).
resource "aws_iam_role" "github_actions" {
  for_each    = local.roles
  name        = "${var.name_prefix}-github-${each.key}"
  description = each.value.description

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = data.aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        # Parentheses make this a dynamic map key — the condition operator
        # (StringLike vs StringEquals) is different for each environment role.
        (each.value.condition_key) = {
          "token.actions.githubusercontent.com:sub" = each.value.sub_value
        }
      }
    }]
  })
}

# Attaches AWS-managed policies (VPC, RDS, Lambda, etc.) to each GitHub Actions role.
resource "aws_iam_role_policy_attachment" "github_actions" {
  for_each   = local.attachments
  role       = aws_iam_role.github_actions[each.value.role_key].name
  policy_arn = each.value.policy_arn
}

# ── Inline Policy: IAM + S3 state + DynamoDB lock ────────────────────────────
# Applied to all three roles. Key security property: iam:CreateRole is only
# allowed when the permission boundary is attached to the new role, blocking
# privilege escalation. S3 and DynamoDB access is scoped to the state bucket prefix.

resource "aws_iam_role_policy" "github_actions_custom" {
  for_each = local.roles
  name     = "terraform-iam-and-state"
  role     = aws_iam_role.github_actions[each.key].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Read access scoped to this role's allowed environments (see local.role_state_read_envs).
        # The dev role reads dev + test buckets; test and prod roles read only their own bucket.
        # flatten() expands the for-comprehension into a flat list of ARN strings, e.g. for dev:
        #   ["arn:aws:s3:::cpiazza01-tf-state-dev-*", "arn:aws:s3:::cpiazza01-tf-state-dev-*/*",
        #    "arn:aws:s3:::cpiazza01-tf-state-test-*", "arn:aws:s3:::cpiazza01-tf-state-test-*/*"]
        Sid    = "TerraformStateRead"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:GetBucketVersioning",
          "s3:GetEncryptionConfiguration",
          "s3:GetBucketPublicAccessBlock"
        ]
        Resource = flatten([
          for env in local.role_state_read_envs[each.key] : [
            "arn:aws:s3:::${var.state_bucket_prefix}-${env}-*",
            "arn:aws:s3:::${var.state_bucket_prefix}-${env}-*/*"
          ]
        ])
      },
      {
        # Write access scoped to this role's own environment bucket only.
        # each.key is "dev", "test", or "prod", matching the bucket name suffix.
        Sid    = "TerraformStateWrite"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "arn:aws:s3:::${var.state_bucket_prefix}-${each.key}-*",
          "arn:aws:s3:::${var.state_bucket_prefix}-${each.key}-*/*"
        ]
      },
      {
        # Lock table access uses the same per-role scoping as TerraformStateRead:
        # dev locks dev + test tables (plan jobs lock test state on PRs);
        # test and prod lock only their own env's table.
        Sid    = "TerraformStateLock"
        Effect = "Allow"
        Action = [
          "dynamodb:DescribeTable",
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Resource = flatten([
          for env in local.role_state_read_envs[each.key] : [
            "arn:aws:dynamodb:*:${data.aws_caller_identity.current.account_id}:table/${var.state_bucket_prefix}-lock-${env}-*"
          ]
        ])
      },
      {
        # Creating roles requires the permission boundary — blocks privilege escalation.
        # Resource is scoped to this account's role namespace; the boundary condition
        # is the primary security control (any role created must carry the boundary).
        Sid      = "IAMCreateRoleWithBoundary"
        Effect   = "Allow"
        Action   = ["iam:CreateRole"]
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/*"
        Condition = {
          StringEquals = {
            "iam:PermissionsBoundary" = aws_iam_policy.lambda_boundary.arn
          }
        }
      },
      {
        # All other IAM role/policy CRUD needed to manage the Lambda execution
        # role lifecycle — update, delete, read, attach/detach policies.
        # Scoped to this account's role and policy namespaces.
        Sid    = "IAMRoleManagement"
        Effect = "Allow"
        Action = [
          "iam:DeleteRole",
          "iam:GetRole",
          "iam:UpdateRole",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:ListRoleTags",
          "iam:CreatePolicy",
          "iam:DeletePolicy",
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:CreatePolicyVersion",
          "iam:DeletePolicyVersion",
          "iam:ListPolicyVersions",
          "iam:TagPolicy",
          "iam:UntagPolicy",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:GetRolePolicy",
          "iam:ListAttachedRolePolicies",
          "iam:ListRolePolicies",
          "iam:ListInstanceProfilesForRole"
        ]
        Resource = [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/*",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/*"
        ]
      },
      {
        # PassRole scoped to Lambda — prevents passing the execution role to
        # any other service. Resource scoped to this account's role namespace.
        Sid      = "PassRoleToLambda"
        Effect   = "Allow"
        Action   = ["iam:PassRole"]
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/*"
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "lambda.amazonaws.com"
          }
        }
      },
      {
        # ACM certificate management for Client VPN (postgres-vpn module).
        # Required when client_vpn_create_certificates = true — the tls provider
        # generates a CA and server/client certs and imports them into ACM.
        Sid    = "ACMCertificateManagement"
        Effect = "Allow"
        Action = [
          "acm:ImportCertificate",
          "acm:DeleteCertificate",
          "acm:DescribeCertificate",
          "acm:ListCertificates",
          "acm:ListTagsForCertificate",
          "acm:AddTagsToCertificate",
          "acm:RemoveTagsFromCertificate"
        ]
        Resource = "*"
      },
      {
        # Creating a Client VPN endpoint triggers AWS to create a service-linked
        # role for clientvpn.amazonaws.com on first use in the account.
        Sid      = "ClientVPNServiceLinkedRole"
        Effect   = "Allow"
        Action   = ["iam:CreateServiceLinkedRole"]
        Resource = "arn:aws:iam::*:role/aws-service-role/clientvpn.amazonaws.com/AWSServiceRoleForClientVPN"
        Condition = {
          StringLike = {
            "iam:AWSServiceName" = "clientvpn.amazonaws.com"
          }
        }
      }
    ]
  })
}
