locals {
  aws_region         = "us-east-1"
  availability_zones = ["us-east-1a", "us-east-1b"]
  tf_state_bucket    = "cpiazza01-tf-state-dev-us-east-1"
  tf_lock_table      = "cpiazza01-tf-state-lock-dev-us-east-1"
}
