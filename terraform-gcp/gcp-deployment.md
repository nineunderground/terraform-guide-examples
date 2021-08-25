## INTRODUCTION

Create a default terraform project to create infra in GCP

```bash
# 1. Create the terraform state bucket using GCP CLI utils
gsutil mb gs://my-terraform-state-bucket-gcp

# For every sub-project:
# 2. Initialize project
GOOGLE_APPLICATION_CREDENTIALS="./credentials.json" terraform init

# 3. Replace proper values in terraform.tfvars if needed

# 4. Create infra (confirmation prompted)
GOOGLE_APPLICATION_CREDENTIALS="./credentials.json" terraform apply
```
