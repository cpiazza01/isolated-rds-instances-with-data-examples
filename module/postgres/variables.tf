# ── Deployment ────────────────────────────────────────────────────────────────

# Target AWS region — must match the region.hcl for this deployment.
variable "aws_region" {
  type        = string
  description = "AWS region to deploy into"
}

# Prefix applied to every resource name and tag, making resources from
# different deployments easy to identify in the AWS console.
variable "name_prefix" {
  type        = string
  description = "Prefix applied to all resource names and tags"
}

# Two AZs are required by RDS for the DB subnet group, even when multi_az = false.
variable "availability_zones" {
  type        = list(string)
  description = "AZs for private subnets — must contain at least two"

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "RDS subnet groups require at least two availability zones."
  }
}

# ── Database ──────────────────────────────────────────────────────────────────

# Controls cost and performance — db.t3.micro is cheapest for dev/test.
variable "db_instance_class" {
  type        = string
  description = "RDS instance size"
}

# Name of the initial database created inside the RDS instance.
variable "db_name" {
  type        = string
  description = "Database name created on the instance"
}

# Master username used to connect to the database.
variable "db_username" {
  type        = string
  description = "Master database username"
}

# Minimum allocated storage in GiB. gp3 storage cannot be shrunk after creation.
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

# Number of rows inserted into the users table by the seeder Lambda after apply.
# Lambda has a 15-minute timeout; ~500,000 rows is the practical maximum.
variable "row_count" {
  type        = number
  description = "Rows to seed into the users table (1–1,000,000)"

  validation {
    condition     = var.row_count >= 1 && var.row_count <= 1000000
    error_message = "row_count must be between 1 and 1,000,000. Note: the seeder Lambda has a 15-minute timeout; values above ~500,000 risk a timeout."
  }
}

# ── Safety Controls ───────────────────────────────────────────────────────────

# Set to false in prod to retain a final snapshot before the instance is deleted.
variable "skip_final_snapshot" {
  type        = bool
  description = "Skip final RDS snapshot on destroy"
}

# Set to true in prod to block terraform destroy from deleting the RDS instance.
variable "db_deletion_protection" {
  type        = bool
  description = "Prevent accidental deletion of the RDS instance"
}

# ── Bastion ───────────────────────────────────────────────────────────────────

# When true, deploys a t3.nano EC2 instance in a public subnet as an SSH
# jump host, enabling local machine → bastion → RDS tunnelling.
variable "enable_bastion" {
  type        = bool
  description = "Deploy a bastion EC2 for SSH-tunnel access to RDS"
}

# Name of a pre-existing EC2 key pair — used to SSH into the bastion host.
variable "bastion_ssh_key_name" {
  type        = string
  description = "Name of an existing EC2 key pair in the target AWS region"
}

# Security group ingress rule on the bastion. Restrict to known IPs in prod.
variable "bastion_allowed_cidrs" {
  type        = list(string)
  description = "CIDRs allowed to SSH to the bastion"

  validation {
    condition     = !contains(var.bastion_allowed_cidrs, "1.2.3.4/32")
    error_message = "Replace the placeholder CIDR (1.2.3.4/32) in prod/env.hcl with your actual office or VPN IP address."
  }
}
