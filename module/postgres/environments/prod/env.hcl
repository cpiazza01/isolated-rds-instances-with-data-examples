# Prod — larger instance, deletion protection on, final snapshot kept on destroy.
# Restrict bastion access to known CIDRs (office IP, VPN exit node, etc.).

locals {
  db_instance_class      = "db.t3.small"
  row_count              = 10000
  skip_final_snapshot    = false
  db_deletion_protection = true
  bastion_allowed_cidrs  = ["1.2.3.4/32"]   # replace with your office/VPN CIDR
}
