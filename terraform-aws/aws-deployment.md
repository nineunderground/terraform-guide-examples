## INTRODUCTION

Create a default terraform project to create infra in AWS

```bash
# 1. Create the terraform state bucket using AWS CLI
aws s3api create-bucket --bucket my-terraform-state-bucket-eu-west-1 --create-bucket-configuration LocationConstraint=eu-west-1

# For every sub-project:
# 2. Initialize project
terraform init

# 3. Replace proper values in terraform.tfvars if needed

# 4. Create infra (confirmation prompted)
terraform apply
```
