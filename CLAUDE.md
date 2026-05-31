# CLAUDE.md

## What this repo is

Terragrunt-managed example deployments of the upstream module
[`github.com/cpiazza01/isolated-rds-instances-with-data`](https://github.com/cpiazza01/isolated-rds-instances-with-data).
That upstream module is also owned by the user, so both repos are under active development together.

Each deployment provisions a private RDS instance (PostgreSQL or MySQL) inside its own VPC,
seeds it with dummy data via a Lambda function, and optionally exposes it through a bastion SSH tunnel.

## Module structure

```
module/
  bootstrap/    # One-time account setup — run manually, NOT via CI
  postgres/     # PostgreSQL 16.3 deployments
  mysql/        # MySQL 8.0 deployments
```

### bootstrap

- Deployed **manually** from `module/bootstrap/environments/account/global/` via `terragrunt apply`.
- Uses **local Terraform state** (cannot use S3 — it creates the S3 buckets).
- Creates: S3 state buckets, DynamoDB lock tables, GitHub Actions IAM roles, Lambda permission boundary.
- CI explicitly skips bootstrap files — changes to `module/bootstrap/` do not trigger CI jobs.
- The `.terraform.lock.hcl` in `module/bootstrap/environments/account/global/` is gitignored (fine — bootstrap runs locally).

### postgres / mysql

- Deployed via GitHub Actions CI on push/PR.
- Each module has `environments/dev/`, `environments/test/`, and `environments/prod/` subdirectories.
- Terragrunt merges `common.hcl` → `env.hcl` → `region.hcl` → inline `name_prefix` for inputs.

## Upstream module ref

Both `postgres/main.tf` and `mysql/main.tf` currently use `?ref=main` for the upstream module source.
This is **intentionally unpinned** — the user is still testing. Once the upstream module is stable,
the plan is to create a version tag and pin to it here. Do not suggest pinning unless asked.

## Terragrunt hierarchy

```
root.terragrunt.hcl          # S3 backend + AWS provider, inherited by all leaf configs
  └── region.hcl             # aws_region, availability_zones, tf_state_bucket, tf_lock_table
      └── env.hcl            # db_instance_class, row_count, safety flags, bastion CIDRs
          └── common.hcl     # db_name, db_username, db_storage_gb, bastion_ssh_key_name
              └── terragrunt.hcl  # merges all of the above, sets name_prefix
```

`find_in_parent_folders()` walks up from the leaf `terragrunt.hcl` to find each config file.
`region.hcl` is the exception — it lives in the *same* directory as the leaf `terragrunt.hcl`
(not a parent), so it is referenced directly via `get_terragrunt_dir()` / `get_original_terragrunt_dir()`
rather than `find_in_parent_folders`.

## State locking

DynamoDB lock tables are created by bootstrap. One table per env/region combination,
named `{state_bucket_prefix}-lock-{env}-{region}` (e.g. `cpiazza01-tf-state-lock-dev-us-east-1`).
The `tf_lock_table` local in each `region.hcl` points to the correct table for that env.

## CI/CD overview

Five workflows:

| Workflow | Trigger | What it does |
|----------|---------|--------------|
| `ci.yml` | Push / PR | Detect changes → test → plan (PRs only) → deploy dev or test |
| `deploy-prod.yml` | Manual dispatch | Test → deploy prod |
| `deploy-lower.yml` | Manual dispatch | plan/apply/destroy dev or test (branch-derived) |
| `destroy-dev.yml` | Nightly (4am UTC) + manual | Destroy all dev deployments |
| `unlock-state.yml` | Manual dispatch | Release a stuck DynamoDB state lock |

Key CI decisions made during development:
- **PRs to main plan against `test`**, not `dev` — reviewers see exactly what merging will deploy.
- `github.event.before` is used (not `HEAD~1`) so multi-commit pushes are fully detected.
- Changes to `env.hcl`, `common.hcl`, and `root.terragrunt.hcl` all trigger re-deploys of affected modules.
- Bootstrap is completely excluded from the CI change-detection loop.

## Running tests locally

```bash
# From any module root (module/postgres/, module/mysql/, module/bootstrap/)
terraform init
terraform test
```

Tests use `mock_provider` — no AWS credentials required. The `row_count_too_low` and
`row_count_too_high` runs use `expect_failures` to verify the validation boundary.

## Key constraints / footguns

- **`prod/env.hcl` has a placeholder CIDR `1.2.3.4/32`** for `bastion_allowed_cidrs`. A variable
  validation rejects this at plan time — replace it with the real office/VPN IP before deploying prod.
- **`db_storage_gb` cannot shrink** after RDS creation (gp3 limitation).
- **`row_count` > ~500,000** risks a Lambda timeout (15-minute limit). The validation allows up to
  1,000,000 but warns about this in the error message.
- **Prod has two destroy guards**: `prevent_destroy = true` in `terragrunt.hcl` AND
  `db_deletion_protection = true` on the RDS instance. Both must be removed before `terragrunt destroy`.
- **Bootstrap state is local** — keep `terraform.tfstate` from `module/bootstrap/environments/account/global/`
  somewhere safe (it is gitignored).

## Provider versions

All modules pin to `>= 6.0, < 7.0` for the AWS provider (matching the bootstrap lock file which
resolved to `6.47.0`). The `archive` and `tls` providers are pinned similarly.
