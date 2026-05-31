# module/bootstrap

One-time account-level setup. Run this before any other module. It creates the S3 state buckets that all other modules store their Terraform state in, plus the GitHub Actions IAM roles used by CI/CD.

**This module uses local Terraform state** — it cannot use S3 for its own state because it creates those buckets. Keep the generated `terraform.tfstate` somewhere safe (version-controlled private repo, or a manually provisioned S3 bucket).

## What it creates

| Resource | Purpose |
|----------|---------|
| S3 buckets (`{prefix}-{env}-{region}`) | Remote state storage for each env/region combination |
| DynamoDB tables (`{prefix}-lock-{env}-{region}`) | State lock tables — one per env/region combination, prevents concurrent applies from corrupting state |
| IAM policy `lambda-boundary` | Permission boundary applied to seeder Lambda execution roles — caps what those roles can do |
| IAM role `…-github-dev` | Assumed by GitHub Actions on any branch push or PR |
| IAM role `…-github-test` | Assumed by GitHub Actions on push to `main` only |
| IAM role `…-github-prod` | Assumed by GitHub Actions when the `prod` GitHub Environment is targeted |

The OIDC provider itself is **not managed here** — it is a pre-existing account-level resource that bootstrap reads via a data source.

## Prerequisites

### Create the GitHub OIDC provider (once per AWS account)

**AWS Console:** IAM → Identity providers → Add provider

| Field | Value |
|-------|-------|
| Provider type | OpenID Connect |
| Provider URL | `https://token.actions.githubusercontent.com` |
| Audience | `sts.amazonaws.com` |

**AWS CLI equivalent:**
```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

## Configuration

Edit `environments/common.hcl` before applying:

| Variable | Description |
|----------|-------------|
| `github_repo` | Your repository in `org/repo` format |
| `name_prefix` | Prefix for all IAM resource names |
| `state_bucket_prefix` | Globally unique prefix for S3 bucket names — include your account alias or username |
| `state_environments` | Environments to create state buckets for (default: `dev`, `test`, `prod`) |
| `state_regions` | Regions to create state buckets in (default: `us-east-1`) |

## Apply

Bootstrap is excluded from CI — tests only run locally. Validate before applying:

```bash
cd module/bootstrap
terraform init
terraform test
```

Then apply:

```bash
cd environments/account/global
terragrunt apply
```

No AWS credentials need to be set in environment variables if your AWS CLI profile is configured. The provider is pinned to `us-east-1` in the bootstrap terragrunt.hcl because IAM and S3 are global services.

## After apply

Copy the role ARNs from the output and set them as GitHub **variables** (not secrets — role
ARNs are identifiers, not credentials; the OIDC trust conditions enforce who can assume them):

```
Settings → Secrets and variables → Actions → Variables → New repository variable
  AWS_ROLE_ARN = <dev role ARN>   ← used by plan jobs on PRs

Settings → Environments → dev → Environment variables
  AWS_ROLE_ARN = <dev role ARN>

Settings → Environments → test → Environment variables
  AWS_ROLE_ARN = <test role ARN>

Settings → Environments → prod → Environment variables
  AWS_ROLE_ARN = <prod role ARN>
```

Configure required reviewers on the `prod` environment to add an approval gate before production deployments.

## Outputs

| Output | Description |
|--------|-------------|
| `lock_table_names` | Map of `{env}-{region}` → DynamoDB table name — already reflected in each `region.hcl` as `tf_lock_table` |
| `state_bucket_names` | Map of `{env}-{region}` → bucket name — already reflected in each `region.hcl` as `tf_state_bucket` |
| `lambda_boundary_arn` | Permission boundary ARN — the RDS modules attach this automatically |
| `oidc_provider_arn` | GitHub OIDC provider ARN (read-only, not managed by bootstrap) |
| `dev_role_arn` | Set as `AWS_ROLE_ARN` in repo-level secrets and the `dev` environment secret |
| `test_role_arn` | Set as `AWS_ROLE_ARN` in the `test` environment secret |
| `prod_role_arn` | Set as `AWS_ROLE_ARN` in the `prod` environment secret |
| `next_steps` | Formatted instructions with the actual ARN values filled in |
