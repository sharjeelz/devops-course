# Creates the S3 bucket that holds Terraform's state for the environments (module 7). It's the one
# piece that can't keep its own state in that bucket (it doesn't exist yet), so this configuration
# keeps a local state file: run it once, keep its terraform.tfstate safe (or re-import later).
#   terraform init && terraform apply -var region=<your region>
terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.68" }
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = { Project = "linkly-course", ManagedBy = "terraform", Environment = "bootstrap" }
  }
}

variable "region" {
  type    = string
  default = "eu-central-1"
}

resource "aws_s3_bucket" "state" {
  bucket_prefix = "linkly-course-tfstate-"
  force_destroy = false # never take state history with it
  lifecycle {
    prevent_destroy = true # terraform destroy refuses: losing state means losing track of everything
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled" # every state change kept: a bad apply can be traced, a broken state restored
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

output "state_bucket" {
  description = "Pass it to the environment: terraform init -backend-config=\"bucket=<this>\""
  value       = aws_s3_bucket.state.bucket
}
