# Dev — small instance, minimal seed data, no production safeguards.
# Bastion is open to all IPs — data is dummy seed data and SSH key auth still protects access.

locals {
  db_instance_class      = "db.t3.micro"
  row_count              = 1000
  skip_final_snapshot    = true
  db_deletion_protection = false
  bastion_allowed_cidrs  = ["0.0.0.0/0"]
}
