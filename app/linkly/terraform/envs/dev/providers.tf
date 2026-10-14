terraform {
  required_version = ">= 1.10" # S3 backend locking without DynamoDB (use_lockfile)
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.68" }
  }
}

provider "aws" {
  region = var.region
  default_tags { # on every resource: how cleanup.sh and your bill find them
    tags = {
      Project     = "linkly-course"
      ManagedBy   = "terraform"
      Environment = "dev"
    }
  }
}
