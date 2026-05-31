output "aws_region" {
  description = "AWS region the stack is deployed into"
  value       = module.isolated_rds.aws_region
}

# Private RDS hostname and port in host:port format. Only reachable from within
# the VPC — connect via the Client VPN tunnel.
output "db_endpoint" {
  description = "RDS connection endpoint (host:port) — only reachable through the VPN tunnel"
  value       = module.isolated_rds.db_endpoint
}

output "db_secret_arn" {
  description = "ARN of the Secrets Manager secret holding the master password. Retrieve with: aws secretsmanager get-secret-value --secret-id <arn> --query SecretString --output text | python -m json.tool"
  value       = module.isolated_rds.db_secret_arn
}

output "seeder_lambda_name" {
  description = "Re-seed the database at any time: aws lambda invoke --function-name <name> --region <region> response.json"
  value       = module.isolated_rds.seeder_lambda_name
}

# ── AWS Client VPN ────────────────────────────────────────────────────────────

# Use this to export the .ovpn client configuration file:
#   $(terraform output -raw client_vpn_config_cmd)
# Then import client-config.ovpn into the AWS VPN Client app.
output "client_vpn_endpoint_id" {
  description = "Client VPN endpoint ID"
  value       = module.isolated_rds.client_vpn_endpoint_id
}

output "client_vpn_dns_name" {
  description = "DNS name of the Client VPN endpoint"
  value       = module.isolated_rds.client_vpn_dns_name
}

output "client_vpn_config_cmd" {
  description = "Ready-to-run command to download the VPN client configuration (.ovpn) file"
  value       = module.isolated_rds.client_vpn_config_cmd
}

# Only populated when client_vpn_create_certificates = true.
# Retrieve a user's cert: terraform output -json client_vpn_client_cert_pem | jq -r '.developer'
output "client_vpn_client_cert_pem" {
  description = "Map of client name to certificate PEM. Empty when client_vpn_create_certificates = false."
  sensitive   = true
  value       = module.isolated_rds.client_vpn_client_cert_pem
}

output "client_vpn_client_key_pem" {
  description = "Map of client name to private key PEM. Empty when client_vpn_create_certificates = false. Keep secret."
  sensitive   = true
  value       = module.isolated_rds.client_vpn_client_key_pem
}
