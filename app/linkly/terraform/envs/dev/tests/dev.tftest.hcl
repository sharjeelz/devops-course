# The dev environment, planned and "applied" against a mock AWS (no account, no credentials).
mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = { names = ["eu-central-1a", "eu-central-1b", "eu-central-1c"] }
  }
  mock_data "aws_ssm_parameter" {
    defaults = { insecure_value = "ami-0123456789abcdef0", value = "ami-0123456789abcdef0" }
  }
}

variables {
  allowed_cidr   = "203.0.113.10/32"
  ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIExampleKeyForTestsOnly learner@laptop"
  linkly_images  = "ghcr.io/learner"
  linkly_tag     = "sha-abc1234"
}

run "builds_the_whole_environment" {
  command = apply
  assert {
    condition     = startswith(output.url, "http://") && endswith(output.url, ":8080")
    error_message = "expected a Linkly URL on port 8080"
  }
  assert {
    condition     = startswith(output.ssh_command, "ssh ec2-user@")
    error_message = "expected an ssh command"
  }
}

run "refuses_ssh_open_to_the_world" {
  command = plan
  variables {
    allowed_cidr = "0.0.0.0/0"
  }
  expect_failures = [var.allowed_cidr]
}

run "refuses_a_range_instead_of_one_address" {
  command = plan
  variables {
    allowed_cidr = "203.0.113.0/24"
  }
  expect_failures = [var.allowed_cidr]
}

run "refuses_a_private_key" {
  command = plan
  variables {
    ssh_public_key = "-----BEGIN OPENSSH PRIVATE KEY-----"
  }
  expect_failures = [var.ssh_public_key]
}

run "refuses_latest" {
  command = plan
  variables {
    linkly_tag = "latest"
  }
  expect_failures = [var.linkly_tag]
}

run "refuses_uppercase_image_paths" {
  command = plan
  variables {
    linkly_images = "ghcr.io/SharjeelZ"
  }
  expect_failures = [var.linkly_images]
}
