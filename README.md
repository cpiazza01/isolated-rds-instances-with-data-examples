# isolated-rds-instances-with-data-examples

Example deployments of the [`isolated-rds-instances-with-data`](https://github.com/cpiazza01/isolated-rds-instances-with-data) Terraform module. Each deployment provisions a private RDS instance inside its own VPC, seeds it with dummy data via a Lambda function, and optionally exposes it through a bastion SSH tunnel.

Two database engines are provided as separate Terragrunt-managed modules:

| Module | Engine | Port |
|--------|--------|------|
| [module/postgres](module/postgres/) | PostgreSQL 16.3 | 5432 |
| [module/mysql](module/mysql/) | MySQL 8.0.35 | 3306 |

## Architecture

```
GitHub Actions (OIDC)
        │
        ▼
   IAM Role (dev / test / prod)
        │
        ▼
  ┌─────────────────────────────────────────┐
  │  VPC (per deployment)                   │
  │  ┌────────────┐    ┌──────────────────┐ │
  │  │  Bastion   │    │  RDS Instance    │ │
  │  │  (public)  │───▶│  (private subnet)│ │
  │  └────────────┘    └──────────────────┘ │
  │                           ▲             │
  │                    ┌──────┴──────┐      │
  │                    │  Seeder     │      │
  │                    │  Lambda     │      │
  │                    └─────────────┘      │
  └─────────────────────────────────────────┘
```

The RDS instance is never publicly accessible. Connect locally via the SSH tunnel command printed after `apply`.

## Repository layout

```
.
├── root.terragrunt.hcl          # Remote state + provider config, inherited by all modules
├── module/
│   ├── bootstrap/               # One-time account setup (S3 buckets, IAM roles, OIDC)
│   ├── postgres/                # PostgreSQL module + environments
│   └── mysql/                   # MySQL module + environments
└── .github/workflows/
    ├── ci.yml                   # Test → plan → deploy dev/test on push/PR
    ├── deploy.yml               # Manual prod deployment
    └── destroy-dev.yml          # Nightly dev teardown (4am UTC)
```

## Prerequisites

- **AWS account** with permissions to create VPCs, RDS, Lambda, IAM, S3, and Secrets Manager resources
- **GitHub OIDC provider** configured in the AWS account (see [bootstrap README](module/bootstrap/README.md))
- **EC2 key pair** in each target region for bastion SSH access
- **Terraform** >= 1.9 and **Terragrunt** >= 0.67 installed locally

## Getting started

### 1. Run bootstrap (one time)

Bootstrap creates the S3 state buckets and GitHub Actions IAM roles. It must run before any other module.

See [module/bootstrap/README.md](module/bootstrap/README.md) for the full setup walkthrough.

### 2. Set GitHub secrets

After bootstrap, copy the role ARNs from its output and set them as GitHub secrets:

| Secret | Where | Value |
|--------|-------|-------|
| `AWS_ROLE_ARN` | Repo-level | dev role ARN (used by plan jobs on PRs) |
| `AWS_ROLE_ARN` | `dev` Environment | dev role ARN |
| `AWS_ROLE_ARN` | `test` Environment | test role ARN |
| `AWS_ROLE_ARN` | `prod` Environment | prod role ARN |

### 3. Configure and deploy

1. Update `module/<engine>/environments/common.hcl` with your EC2 key pair name.
2. Update `module/<engine>/environments/prod/env.hcl` with your office/VPN CIDR.
3. Push to a feature branch — GitHub Actions deploys to `dev` automatically.

## CI/CD pipeline

| Event | Jobs |
|-------|------|
| Push to any branch | Test → deploy to `dev` |
| Pull request to `main` | Test → plan against `dev` |
| Push to `main` | Test → deploy to `test` |
| Manual dispatch (`deploy.yml`) | Test → deploy to `prod` (requires `prod` environment approval) |
| Nightly schedule (`destroy-dev.yml`) | Destroy all `dev` deployments at 4am UTC |

Only modules with changed files are included in each run. New modules are picked up automatically by the destroy workflow without any workflow edits.

## Environments

| Environment | Instance | Rows seeded | Bastion CIDRs | Deletion protection |
|-------------|----------|-------------|---------------|---------------------|
| dev | db.t3.micro | 1,000 | `0.0.0.0/0` | off |
| test | db.t3.micro | 5,000 | `0.0.0.0/0` | off |
| prod | db.t3.small | 10,000 | configurable | on |
