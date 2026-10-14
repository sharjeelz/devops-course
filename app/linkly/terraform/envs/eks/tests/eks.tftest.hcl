# The EKS environment, planned and "applied" against a mock AWS (no account, no credentials).
mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = { names = ["eu-central-1a", "eu-central-1b", "eu-central-1c"] }
  }
  mock_resource "aws_db_instance" {
    defaults = {
      address            = "linkly-course-eks.abc123.eu-central-1.rds.amazonaws.com"
      master_user_secret = [{ secret_arn = "arn:aws:secretsmanager:eu-central-1:123456789012:secret:rds!db-123-AbCdEf", kms_key_id = "k", secret_status = "active" }]
    }
  }
  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::123456789012:role/mock" }
  }
  mock_resource "aws_subnet" {
    defaults = { id = "subnet-0mock" }
  }
}

variables {
  allowed_cidr = "203.0.113.10/32"
}

run "builds_cluster_and_database" {
  command = apply
  assert {
    condition     = output.db_host == "linkly-course-eks.abc123.eu-central-1.rds.amazonaws.com"
    error_message = "db_host output expected"
  }
  assert {
    condition     = output.db_secret_arn == "arn:aws:secretsmanager:eu-central-1:123456789012:secret:rds!db-123-AbCdEf"
    error_message = "db_secret_arn output expected"
  }
  assert {
    condition     = output.kubeconfig_command == "aws eks update-kubeconfig --name linkly-course --region eu-central-1"
    error_message = "a ready-to-run kubeconfig command expected"
  }
}

run "refuses_an_open_api_endpoint" {
  command = plan
  variables {
    allowed_cidr = "0.0.0.0/0"
  }
  expect_failures = [var.allowed_cidr]
}
