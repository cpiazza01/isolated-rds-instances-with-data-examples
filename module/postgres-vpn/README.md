# module/postgres-vpn

Deploys a private PostgreSQL 16 RDS instance inside its own VPC. A seeder Lambda populates the database with dummy data after apply. An AWS Client VPN endpoint provides network-level access to the private VPC — no bastion host required.

> **Cost note:** AWS Client VPN charges ~$0.10/hr per subnet association. With two AZs this is ~$144/month even when idle. Dev deployments are destroyed nightly at 4am UTC by the scheduled workflow; use `deploy-lower.yml` destroy to tear down test when not needed.

## Prerequisites

- Bootstrap has been applied (S3 state buckets must exist)
- [AWS VPN Client](https://aws.amazon.com/vpn/client-vpn-download/) installed locally
- **For prod only:** EasyRSA (or equivalent) to generate and import server and CA certificates into ACM (see `environments/prod/env.hcl` for the full walkthrough)

## Configuration

Configuration is split across three HCL files that Terragrunt merges at deploy time:

### `environments/common.hcl` — shared across all environments

| Variable | Default | Description |
|----------|---------|-------------|
| `db_name` | `appdb` | Database name created on the instance |
| `db_username` | `dbadmin` | Master username |
| `db_storage_gb` | `20` | Allocated storage in GiB (cannot shrink after creation) |
| `client_vpn_cidr` | `172.16.0.0/22` | Client IP pool — must not overlap with the VPC CIDR (`10.102.0.0/16`) |
| `client_vpn_client_names` | `["developer"]` | One certificate/key pair is generated per name when `client_vpn_create_certificates = true` |
| `client_vpn_split_tunnel` | `true` | Route only VPC traffic through the VPN; clients keep their normal internet path |
| `client_vpn_enable_connection_logging` | `false` | Overridden to `true` in prod |

### `environments/<env>/env.hcl` — per-environment overrides

| Variable | dev | test | prod |
|----------|-----|------|------|
| `db_instance_class` | `db.t3.micro` | `db.t3.micro` | `db.t3.small` |
| `row_count` | `1,000` | `5,000` | `10,000` |
| `skip_final_snapshot` | `true` | `true` | `false` |
| `db_deletion_protection` | `false` | `false` | `true` |
| `client_vpn_create_certificates` | `true` | `true` | `false` |
| `client_vpn_server_cert_arn` | — | — | *(set manually — see prod/env.hcl)* |
| `client_vpn_root_cert_arn` | — | — | *(set manually — see prod/env.hcl)* |
| `client_vpn_enable_connection_logging` | `false` | `false` | `true` |

Dev and test auto-generate certificates via the `tls` provider; private keys are stored in Terraform state (acceptable for non-production). For prod, generate certificates with EasyRSA, import them into ACM, and set the ARNs in `prod/env.hcl` before deploying.

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
cd module/postgres-vpn/environments/<env>/<region>
terragrunt apply
```

## Outputs

| Output | Description |
|--------|-------------|
| `aws_region` | Region the stack is deployed into |
| `db_endpoint` | `host:port` — only reachable through the VPN tunnel |
| `db_secret_arn` | Secrets Manager ARN holding the auto-generated master password |
| `db_password_command` | Ready-to-run command to retrieve the master password |
| `seeder_lambda_name` | Lambda function name for manual re-seeding |
| `client_vpn_endpoint_id` | Client VPN endpoint ID |
| `client_vpn_dns_name` | DNS name of the Client VPN endpoint |
| `client_vpn_config_cmd` | Ready-to-run command to download the `.ovpn` client configuration |
| `client_vpn_client_cert_pem` | Map of client name → certificate PEM (sensitive; empty when `client_vpn_create_certificates = false`) |
| `client_vpn_client_key_pem` | Map of client name → private key PEM (sensitive; keep secret) |
| `client_vpn_connection_guide` | Full step-by-step connection guide |

## Connecting to the database

```bash
# 1. Download the VPN client configuration
$(terragrunt output -raw client_vpn_config_cmd)
# This writes client-config.ovpn to your current directory.

# 2. If auto-generated certificates were used (dev/test), extract the client cert and key
#    and paste them into client-config.ovpn before importing:
terragrunt output -json client_vpn_client_cert_pem | jq -r '.developer'
terragrunt output -json client_vpn_client_key_pem  | jq -r '.developer'

# 3. Import client-config.ovpn into the AWS VPN Client app and connect.

# 4. Retrieve the database password
$(terragrunt output -raw db_password_command)

# 5. Connect with psql (the RDS endpoint is reachable while the VPN is connected)
psql -h $(terragrunt output -raw db_endpoint | cut -d: -f1) \
     -p 5432 -U dbadmin -d appdb
```

## Re-seeding the database

The seeder Lambda runs automatically after `apply`. To trigger it manually without a full re-apply:

```bash
aws lambda invoke \
  --function-name $(terragrunt output -raw seeder_lambda_name) \
  --region $(terragrunt output -raw aws_region) \
  response.json
```

## Destroy

```bash
cd module/postgres-vpn/environments/<env>/<region>
terragrunt destroy
```

Prod has `prevent_destroy = true` in its `terragrunt.hcl` and `db_deletion_protection = true` on the RDS instance. Both must be removed before a prod destroy can proceed.
