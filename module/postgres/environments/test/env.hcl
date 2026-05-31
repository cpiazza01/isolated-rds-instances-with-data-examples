# Test — same size as dev but a larger seed dataset for integration testing.
# Bastion is open to all IPs — data is dummy seed data and SSH key auth still protects access.

locals {
  db_instance_class      = "db.t3.micro"
  row_count              = 5000
  skip_final_snapshot    = true
  db_deletion_protection = false
  bastion_allowed_cidrs  = ["0.0.0.0/0"]
}
