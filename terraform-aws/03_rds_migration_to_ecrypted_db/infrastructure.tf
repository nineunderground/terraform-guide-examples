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

variable "tags" {
    description = "TAGS"
    type        = map(string)
}

variable "not_encrypted_snapshot_identifier" {
    description = "RDS Snapshot"
    type        = string
}

variable "encrypted_snapshot_identifier" {
    description = "RDS Snapshot"
    type        = string
}

variable "encryption_kms_key_id" {
    description = "RDS KMS key id"
    type        = string
}

variable "rds_subnet_group" {
    description = "VPC id"
    type        = string
}

variable "db_type" {
    description = "CPU Type for DB instance"
    type        = string
}

variable "rds_db_name" {
    description = "RDS Database item name"
    type        = string
}

variable "db_engine" {
    description = "RDS Database engine"
    type        = string
}

variable "db_engine_version" {
    description = "RDS Database enmgine version"
    type        = string
}

variable "db_engine_parameter_group" {
    description = "RDS Database Parameter Group"
    type        = string
}

variable "db_source_identifier" {
    description = "RDS Database from where create the DB snapshot"
    type        = string
}

variable "db_dns_recordset" {
    description = "RDS Database DNS record"
    type        = string
}

variable "db_r53_hosted_zone_id" {
    description = "R53 hosted zone where DNS recordset will be created"
    type        = string
}

###########################################################################
# DATA SOURCES
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_availability_zones" "current" {}

###########################################################################
# RESOURCES

# Encrypt the provided snapshot
resource "aws_db_snapshot" "manual_snapshot_creation" {
  db_instance_identifier = var.db_source_identifier
  db_snapshot_identifier = var.not_encrypted_snapshot_identifier
}

# Encrypt the provided snapshot
resource "null_resource" "snapshot_encryption" {
    # depends_on = [time_sleep.wait_8_minutes_for_snapshot_creation]
    depends_on = [aws_db_snapshot.manual_snapshot_creation]

    provisioner "local-exec" {
        command = "aws --profile assumed-role rds copy-db-snapshot --source-db-snapshot-identifier ${var.not_encrypted_snapshot_identifier} --target-db-snapshot-identifier ${var.encrypted_snapshot_identifier} --kms-key-id ${var.encryption_kms_key_id}"
    }

    # Trigger based on param needed. Otherwise this resource is re-created all the time terraform apply is running
    triggers = {
        snapshot_origin = "${var.not_encrypted_snapshot_identifier}"
    }
}

resource "time_sleep" "wait_8_minutes_for_snapshot_encryption" {
    depends_on = [null_resource.snapshot_encryption]
    create_duration = "480s" // 60*8 = 480 
}

# RDS Instance to create a encrypted database, from dbm4 snapshot
resource "aws_db_instance" "encrypted_db" {
    depends_on = [time_sleep.wait_8_minutes_for_snapshot_encryption]

    # NOTE: Not needed these attributes because this is a restore DB resource
    #username             = "N/A"
    #password             = "N/A"
    identifier           = var.rds_db_name
    parameter_group_name = var.db_engine_parameter_group
    snapshot_identifier  = join(":", ["arn","aws","rds", data.aws_region.current.name, data.aws_caller_identity.current.account_id, "snapshot", var.encrypted_snapshot_identifier]) // e.g. arn:aws:rds:eu-west-1:123456789012:snapshot:db-encrypted"
    storage_encrypted    = true
    skip_final_snapshot  = true
    multi_az             = true
    engine               = var.db_engine
    engine_version       = var.db_engine_version
    instance_class       = var.db_type
    copy_tags_to_snapshot = true

    # vpc mode vpc_id
    db_subnet_group_name = var.rds_subnet_group
}

# DNS record
resource "aws_route53_record" "db_url" {
    depends_on = [aws_db_instance.encrypted_db]

    zone_id = var.db_r53_hosted_zone_id
    name    = var.db_dns_recordset
    type    = "CNAME"
    ttl     = "300"
    records = [aws_db_instance.encrypted_db.address]
}

###############################################################

# OUTPUTS
output "db_encrypted_url" {
    value = aws_db_instance.encrypted_db.address
}
