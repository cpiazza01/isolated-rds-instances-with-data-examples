# module/postgres

Deploys a private PostgreSQL 16 RDS instance inside its own VPC. A seeder Lambda populates the database with dummy data after apply. An optional bastion EC2 host provides SSH tunnel access to the private endpoint.

## Prerequisites

- Bootstrap has been applied (S3 state buckets must exist)
- An EC2 key pair exists in each target region for bastion SSH access

## Configuration

Configuration is split across three HCL files that Terragrunt merges at deploy time:

### `environments/common.hcl` — shared across all environments

| Variable | Default | Description |
|----------|---------|-------------|
| `db_name` | `appdb` | Database name created on the instance |
| `db_username` | `dbadmin` | Master username |
| `db_storage_gb` | `20` | Allocated storage in GiB (cannot shrink after creation) |
| `enable_bastion` | `true` | Deploy a bastion EC2 for SSH tunnel access |
| `bastion_ssh_key_name` | `my-rds-key` | Name of an existing EC2 key pair in the target region |

Update `bastion_ssh_key_name` to match a key pair you have the private key for.

### `environments/<env>/env.hcl` — per-environment overrides

| Variable | dev | test | prod |
|----------|-----|------|------|
| `db_instance_class` | `db.t3.micro` | `db.t3.micro` | `db.t3.small` |
| `row_count` | `1,000` | `5,000` | `10,000` |
| `skip_final_snapshot` | `true` | `true` | `false` |
| `db_deletion_protection` | `false` | `false` | `true` |
| `bastion_allowed_cidrs` | `["0.0.0.0/0"]` | `["0.0.0.0/0"]` | `["1.2.3.4/32"]` |

Update `bastion_allowed_cidrs` in `prod/env.hcl` to your office or VPN CIDR before deploying to prod.

### `environments/<env>/<region>/region.hcl` — per-region config

| Variable | Description |
|----------|-------------|
| `aws_region` | Target AWS region |
| `availability_zones` | Two AZs for the RDS subnet group |
| `tf_state_bucket` | S3 bucket name for Terraform state (created by bootstrap) |
| `tf_lock_table` | DynamoDB lock table name for state locking (created by bootstrap) |

## Deploy

CI/CD handles deployment automatically (see [root README](../../README.md#cicd-pipeline)). To deploy manually:

```bash
cd module/postgres/environments/<env>/<region>
terragrunt apply
```

## Outputs

| Output | Description |
|--------|-------------|
| `aws_region` | Region the stack is deployed into |
| `db_endpoint` | `host:port` — only reachable through the SSH tunnel |
| `db_secret_arn` | Secrets Manager ARN holding the auto-generated master password |
| `seeder_lambda_name` | Lambda function name for manual re-seeding |
| `bastion_public_ip` | Public IP of the bastion host |
| `bastion_ssh_tunnel_command` | Ready-to-run SSH command that forwards `localhost:5432` to the RDS endpoint |
| `bastion_instance_id` | EC2 instance ID for starting/stopping the bastion |
| `bastion_connection_guide` | Full step-by-step connection guide (null when `enable_bastion = false`) |
| `db_password_command` | Ready-to-run command to retrieve the master password |

## Connecting to the database

```bash
# Open the SSH tunnel (runs in the foreground — keep this terminal open)
$(terragrunt output -raw bastion_ssh_tunnel_command)

# In another terminal, retrieve the password
aws secretsmanager get-secret-value \
  --secret-id $(terragrunt output -raw db_secret_arn) \
  --query SecretString --output text | python -m json.tool

# Connect with psql
psql -h localhost -p 5432 -U dbadmin -d appdb
```

## Re-seeding the database

The seeder Lambda runs automatically after `apply`. To trigger it manually without a full re-apply:

```bash
aws lambda invoke \
  --function-name $(terragrunt output -raw seeder_lambda_name) \
  --region $(terragrunt output -raw aws_region) \
  response.json
```

## Saving on costs

The bastion is a `t3.nano` instance that incurs a small hourly charge when running. Stop it when not in use:

```bash
aws ec2 stop-instances \
  --instance-ids $(terragrunt output -raw bastion_instance_id) \
  --region $(terragrunt output -raw aws_region)
```

Start it again before opening an SSH tunnel:

```bash
aws ec2 start-instances \
  --instance-ids $(terragrunt output -raw bastion_instance_id) \
  --region $(terragrunt output -raw aws_region)
```

Dev deployments are destroyed automatically every night at 4am UTC by the scheduled workflow.

## Destroy

```bash
cd module/postgres/environments/<env>/<region>
terragrunt destroy
```

Prod has `prevent_destroy = true` in its `terragrunt.hcl` and `db_deletion_protection = true` on the RDS instance. Both must be removed before a prod destroy can proceed.
