# Test — same size as dev but a larger seed dataset for integration testing.
# Certificates are auto-generated (private keys stored in Terraform state —
# acceptable for test; use manually managed certs in prod).
#
# NOTE: AWS Client VPN costs ~$0.10/hr per subnet association (~$144/month idle).

locals {
  db_instance_class      = "db.t3.micro"
  row_count              = 5000
  skip_final_snapshot    = true
  db_deletion_protection = false

  client_vpn_create_certificates = true
}
