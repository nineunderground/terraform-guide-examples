// TERRAFORM & AWS CONFIG
// This bucket must be created using CLI before setup terraform to be used as state
// aws s3api create-bucket --bucket my-terraform-state-bucket-eu-west-1 --create-bucket-configuration LocationConstraint=eu-west-1
terraform {
  backend "s3" {
    bucket = "my-terraform-state-bucket-eu-west-1"
    key    = "terraform/aws/state"
    profile = "assumed-role"
    region = "eu-west-1"
  }
}
