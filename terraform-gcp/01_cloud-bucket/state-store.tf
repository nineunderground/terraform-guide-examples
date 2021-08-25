terraform {
  backend "gcs"{
    bucket      = "my-terraform-state-bucket-gcp"
    prefix      = "terraform/gcp/state"
  }
}