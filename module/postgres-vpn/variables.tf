# ── Deployment ────────────────────────────────────────────────────────────────

variable "aws_region" {
  type        = string
  description = "AWS region to deploy into"
}

variable "name_prefix" {
  type        = string
  description = "Prefix applied to all resource names and tags"
}

variable "availability_zones" {
  type        = list(string)
  description = "AZs for private subnets — must contain at least two"

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "RDS subnet groups require at least two availability zones."
  }
}

# ── Database ──────────────────────────────────────────────────────────────────

variable "db_instance_class" {
  type        = string
  description = "RDS instance size"
}

variable "db_name" {
  type        = string
  description = "Database name created on the instance"
}

variable "db_username" {
  type        = string
  description = "Master database username"
}

variable "db_storage_gb" {
  type        = number
  description = "Allocated storage in GiB"

  validation {
    condition     = var.db_storage_gb >= 20
    error_message = "AWS RDS requires at least 20 GiB of storage for gp3."
  }
}

# ── Seeder Lambda ─────────────────────────────────────────────────────────────

# ARN of the IAM permission boundary policy created by bootstrap. The GitHub
# Actions IAMCreateRoleWithBoundary condition requires this to be attached to
# any role the seeder Lambda execution role creates.
variable "lambda_permission_boundary_arn" {
  type        = string
  description = "Permission boundary ARN (from bootstrap output lambda_boundary_arn) to attach to the seeder Lambda execution role"
}

variable "row_count" {
  type        = number
  description = "Rows to seed into the users table (1–1,000,000)"

  validation {
    condition     = var.row_count >= 1 && var.row_count <= 1000000
    error_message = "row_count must be between 1 and 1,000,000. Note: the seeder Lambda has a 15-minute timeout; values above ~500,000 risk a timeout."
  }
}

# ── Safety Controls ───────────────────────────────────────────────────────────

variable "skip_final_snapshot" {
  type        = bool
  description = "Skip final RDS snapshot on destroy"
}

variable "db_deletion_protection" {
  type        = bool
  description = "Prevent accidental deletion of the RDS instance"
}

# ── AWS Client VPN ────────────────────────────────────────────────────────────
#
# Cost: $0.10/hr per subnet association. With two AZs that is ~$144/month even
# when no clients are connected. Use destroy-dev.yml nightly teardown or
# deploy-lower.yml destroy to avoid idle charges in dev/test.

# Must not overlap with the VPC CIDR (10.0.0.0/16 by default).
variable "client_vpn_cidr" {
  type        = string
  description = "CIDR block for VPN client IPs — must not overlap with the VPC CIDR"
  default     = "172.16.0.0/22"
}

# When true, a CA and certificates are generated automatically by the tls
# provider and imported into ACM — no manual PKI setup required. Private keys
# are stored in Terraform state. Acceptable for dev/test; use false for prod.
variable "client_vpn_create_certificates" {
  type        = bool
  description = "Auto-generate and import ACM certificates. Private keys will be stored in Terraform state. Use false for production — provide cert ARNs manually."
}

# Required when client_vpn_create_certificates = false (production).
# Generate via EasyRSA, import into ACM, then set here.
variable "client_vpn_server_cert_arn" {
  type        = string
  description = "ACM certificate ARN for the VPN server. Required when client_vpn_create_certificates = false."
  default     = null
}

variable "client_vpn_root_cert_arn" {
  type        = string
  description = "ACM CA certificate ARN for client authentication. Required when client_vpn_create_certificates = false."
  default     = null
}

validation {
  condition = (
    var.client_vpn_create_certificates ||
    (var.client_vpn_server_cert_arn != null && var.client_vpn_root_cert_arn != null)
  )
  error_message = "client_vpn_server_cert_arn and client_vpn_root_cert_arn are required when client_vpn_create_certificates = false. Import your server and CA certificates into ACM and set these values in prod/env.hcl."
}

# One certificate/key pair is generated per entry when create_certificates = true.
# Remove a name and re-apply to revoke that user's access without affecting others.
variable "client_vpn_client_names" {
  type        = list(string)
  description = "VPN client names. One cert/key pair is generated per entry when client_vpn_create_certificates = true."
  default     = ["developer"]
}

variable "client_vpn_enable_connection_logging" {
  type        = bool
  description = "Write VPN connection events to CloudWatch Logs. Recommended for production."
  default     = false
}

# Split tunnel routes only VPC traffic through the VPN; clients keep their
# existing internet path for everything else. Reduces cost and latency.
variable "client_vpn_split_tunnel" {
  type        = bool
  description = "Route only VPC traffic through the VPN (true) or all client traffic (false)."
  default     = true
}
