# Region the stack was deployed into — useful when constructing CLI commands
# that require --region (e.g. aws secretsmanager get-secret-value).
output "aws_region" {
  description = "AWS region the stack is deployed into"
  value       = module.isolated_rds.aws_region
}

# Private RDS hostname and port in host:port format. Only reachable from within
# the VPC — connect via the bastion SSH tunnel or Client VPN.
output "db_endpoint" {
  description = "RDS connection endpoint (host:port) — only reachable through the SSH tunnel"
  value       = module.isolated_rds.db_endpoint
}

# ARN of the Secrets Manager secret that holds the auto-generated master password.
# The password is never stored in Terraform state — retrieve it on demand with:
#   aws secretsmanager get-secret-value --secret-id <arn> \
#     --query SecretString --output text | python -m json.tool
output "db_secret_arn" {
  description = "ARN of the Secrets Manager secret holding the master password. Retrieve with: aws secretsmanager get-secret-value --secret-id <arn> --query SecretString --output text | python -m json.tool"
  value       = module.isolated_rds.db_secret_arn
}

# Name of the seeder Lambda. Invoke it manually to re-seed the database without
# a full terraform apply:
#   aws lambda invoke --function-name <name> --region <region> response.json
output "seeder_lambda_name" {
  description = "Re-seed the database at any time: aws lambda invoke --function-name <name> --region <region> response.json"
  value       = module.isolated_rds.seeder_lambda_name
}

# Public IP of the bastion EC2 host — use this to build custom SSH tunnels or
# to whitelist the IP in other security groups.
output "bastion_public_ip" {
  description = "Public IP of the bastion host"
  value       = module.isolated_rds.bastion_public_ip
}

# Complete SSH tunnel command, ready to paste. Opens a local port 5432 that
# forwards to the RDS private endpoint through the bastion:
#   $(terraform output -raw bastion_ssh_tunnel_command)
output "bastion_ssh_tunnel_command" {
  description = "Ready-to-run SSH tunnel command — forwards localhost:5432 to the RDS private endpoint"
  value       = module.isolated_rds.bastion_ssh_tunnel_command
}

# EC2 instance ID of the bastion host. Use this to start or stop the bastion
# from the CLI to avoid costs when not in use:
#   aws ec2 stop-instances --instance-ids <id>
output "bastion_instance_id" {
  description = "EC2 instance ID — use to start/stop the bastion: aws ec2 start-instances --instance-ids <id>"
  value       = module.isolated_rds.bastion_instance_id
}

output "bastion_connection_guide" {
  description = "Full step-by-step connection guide for reaching RDS via the bastion tunnel (null when enable_bastion = false)."
  value = module.isolated_rds.bastion_connection_guide
}

output "db_password_command" {
  description = "Ready-to-run command to retrieve the RDS master password."
  value       = module.isolated_rds.db_password_command
}