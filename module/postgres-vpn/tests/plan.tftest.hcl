# Plan-only tests using mock providers — no AWS credentials required.
# Validates that the module produces a valid plan for different environment configurations.
#
# override_module replaces the upstream isolated_rds module call with static mock
# outputs. Without this, the upstream module's own provider "aws" {} block would
# attempt to initialise a real provider even though mock_provider is set at the
# root level — the two are separate provider configurations.

mock_provider "aws" {}
mock_provider "archive" {}
mock_provider "tls" {}

override_module {
  target = module.isolated_rds
  outputs = {
    aws_region                  = "us-east-1"
    db_endpoint                 = "localhost:5432"
    db_secret_arn               = "arn:aws:secretsmanager:us-east-1:123456789012:secret:test"
    db_password_command         = "aws secretsmanager get-secret-value --secret-id arn:aws:secretsmanager:us-east-1:123456789012:secret:test --query SecretString --output text | python -m json.tool"
    seeder_lambda_name          = "test-seeder"
    client_vpn_endpoint_id      = "cvpn-endpoint-0123456789abcdef0"
    client_vpn_dns_name         = "cvpn-endpoint-0123456789abcdef0.prod.clientvpn.us-east-1.amazonaws.com"
    client_vpn_config_cmd       = "aws ec2 export-client-vpn-client-configuration --client-vpn-endpoint-id cvpn-endpoint-0123456789abcdef0 --region us-east-1 --output text > client-config.ovpn"
    client_vpn_client_cert_pem  = {}
    client_vpn_client_key_pem   = {}
    client_vpn_connection_guide = "1. Download the .ovpn config.\n2. Import into AWS VPN Client and connect.\n3. Connect with psql on the RDS private endpoint."
  }
}

# Baseline variable values shared across all runs.
variables {
  aws_region         = "us-east-1"
  name_prefix        = "test-pg-vpn"
  vpc_cidr           = "10.0.0.0/16"
  availability_zones = ["us-east-1a", "us-east-1b"]

  db_instance_class = "db.t3.micro"
  db_name           = "appdb"
  db_username       = "dbadmin"
  db_storage_gb     = 20

  lambda_permission_boundary_arn = "arn:aws:iam::123456789012:policy/test-lambda-boundary"

  row_count              = 100
  skip_final_snapshot    = true
  db_deletion_protection = false

  client_vpn_create_certificates = true
}

run "dev_config" {
  command = plan

  assert {
    condition     = var.db_deletion_protection == false
    error_message = "dev should not have deletion protection enabled"
  }

  assert {
    condition     = var.skip_final_snapshot == true
    error_message = "dev should skip the final snapshot"
  }

  assert {
    condition     = var.client_vpn_create_certificates == true
    error_message = "dev should auto-generate VPN certificates (private keys in state is acceptable for dev)"
  }
}

run "prod_config" {
  command = plan

  variables {
    db_instance_class      = "db.t3.small"
    row_count              = 10000
    skip_final_snapshot    = false
    db_deletion_protection = true

    # Prod uses manual certificates — auto-generation stores keys in state.
    client_vpn_create_certificates = false
    client_vpn_server_cert_arn     = "arn:aws:acm:us-east-1:123456789012:certificate/server-cert"
    client_vpn_root_cert_arn       = "arn:aws:acm:us-east-1:123456789012:certificate/ca-cert"
  }

  assert {
    condition     = var.db_deletion_protection == true
    error_message = "prod must have deletion protection enabled"
  }

  assert {
    condition     = var.skip_final_snapshot == false
    error_message = "prod must retain a final snapshot on destroy"
  }

  assert {
    condition     = var.client_vpn_create_certificates == false
    error_message = "prod should use manually managed certificates"
  }

  assert {
    condition     = var.client_vpn_enable_connection_logging == true
    error_message = "prod must enable VPN connection logging for the audit trail"
  }
}

run "prod_missing_cert_arns" {
  command = plan

  variables {
    client_vpn_create_certificates = false
    client_vpn_server_cert_arn     = null
    client_vpn_root_cert_arn       = null
  }

  expect_failures = [var.client_vpn_server_cert_arn]
}

run "row_count_too_low" {
  command = plan

  variables {
    row_count = 0
  }

  expect_failures = [var.row_count]
}

run "row_count_too_high" {
  command = plan

  variables {
    row_count = 1000001
  }

  expect_failures = [var.row_count]
}

run "availability_zones_too_few" {
  command = plan

  variables {
    availability_zones = ["us-east-1a"]
  }

  expect_failures = [var.availability_zones]
}

run "db_storage_too_small" {
  command = plan

  variables {
    db_storage_gb = 19
  }

  expect_failures = [var.db_storage_gb]
}
