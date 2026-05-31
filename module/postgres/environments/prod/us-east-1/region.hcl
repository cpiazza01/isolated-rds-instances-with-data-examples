locals {
  aws_region         = "us-east-1"
  availability_zones = ["us-east-1a", "us-east-1b"]
  tf_state_bucket    = "cpiazza01-tf-state-prod-us-east-1"
  tf_lock_table      = "cpiazza01-tf-state-lock-prod-us-east-1"
}
