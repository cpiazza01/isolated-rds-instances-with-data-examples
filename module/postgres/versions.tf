# Provider version constraints for this module.
# aws     — all VPC, RDS, EC2, Lambda, IAM, and Secrets Manager resources.
# archive — zips the Lambda deployment package at apply time.
# tls     — generates PKI certificates if Client VPN is enabled in the upstream module.
terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0, < 7.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.0, < 3.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0, < 5.0"
    }
  }
}
