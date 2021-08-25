###########################################################################
# TERRAFORM & AWS CONFIG
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.36"
    }
  }
}

provider "aws" {
  region  = "eu-west-1"
}

###########################################################################
# VARIABLES

variable "my_tags" {
  description = "Custom Tags"
  type        = map(string)
}

###########################################################################
# RESOURCES

# S3 BUCKET 
resource "aws_s3_bucket" "simple_bucket" {
  bucket = "my-own-bucket"
  acl    = "private"
  versioning {
    enabled = false
  }
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
  tags = var.my_tags
}

###########################################################################
# OUTPUTS

output "bucket_arn" {
  value = aws_s3_bucket.simple_bucket.arn
}
