# Dev — small instance, minimal seed data, no production safeguards.
# Certificates are auto-generated (private keys stored in Terraform state —
# acceptable for dev; use manually managed certs in prod).
#
# NOTE: AWS Client VPN costs ~$0.10/hr per subnet association. With two AZs
# that is ~$144/month even when idle. The nightly destroy-dev.yml teardown
# removes the endpoint every night to avoid accumulating charges.

locals {
  db_instance_class      = "db.t3.micro"
  row_count              = 1000
  skip_final_snapshot    = true
  db_deletion_protection = false

  client_vpn_create_certificates = true
}
