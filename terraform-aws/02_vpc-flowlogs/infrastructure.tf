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
  profile = "assumed-role"
  region  = "eu-west-1"
}

###########################################################################
# VARIABLES
variable "aws_vpcflowlogs_bucket" {
  description = "S3 bucket where all VPC logs are forwarded"
  type        = string
}

variable "tags" {
  description = "Valid tags"
  type        = map(string)
}

data "aws_caller_identity" "current" {}

# LOCALS (TODO: Replace the IDs with right VPCs)
locals {
  vpcs = [
    { id = "vpc-XXXXXXXX" },
    { id = "vpc-XXXXXXXX" },
    { id = "vpc-XXXXXXXX" },
  ]
}

###########################################################################
# RESOURCES

resource "aws_flow_log" "aws_vpc_id" {
  count                = length(local.vpcs)
  log_destination      = join("", ["arn:aws:s3:::", var.aws_vpcflowlogs_bucket])
  log_destination_type = "s3"
  traffic_type         = "ALL"
  vpc_id               = local.vpcs[count.index].id
  tags                 = var.tags
}

###############################################################

# OUTPUTS
# N/A