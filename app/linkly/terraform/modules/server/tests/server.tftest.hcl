mock_provider "aws" {
  mock_data "aws_ssm_parameter" {
    defaults = { insecure_value = "ami-0123456789abcdef0", value = "ami-0123456789abcdef0" }
  }
}

variables {
  name              = "linkly-course"
  vpc_id            = "vpc-0123456789abcdef0"
  subnet_id         = "subnet-0123456789abcdef0"
  allowed_cidr      = "203.0.113.10/32"
  ssh_public_key    = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIExampleKeyForTestsOnly learner@laptop"
  linkly_images     = "ghcr.io/learner"
  linkly_tag        = "sha-abc1234"
  backup_bucket_arn = "arn:aws:s3:::linkly-course-backups-123"
}

run "only_one_address_reaches_ssh_and_linkly" {
  command = plan
  assert {
    condition     = aws_vpc_security_group_ingress_rule.ssh.cidr_ipv4 == "203.0.113.10/32" && aws_vpc_security_group_ingress_rule.ssh.from_port == 22
    error_message = "SSH must be open only to allowed_cidr"
  }
  assert {
    condition     = aws_vpc_security_group_ingress_rule.web.cidr_ipv4 == "203.0.113.10/32" && aws_vpc_security_group_ingress_rule.web.from_port == 8080
    error_message = "Linkly (8080) must be open only to allowed_cidr"
  }
}

run "hardened_instance" {
  command = plan
  assert {
    condition     = one(aws_instance.this.metadata_options).http_tokens == "required"
    error_message = "IMDSv2 must be required"
  }
  assert {
    condition     = one(aws_instance.this.metadata_options).http_put_response_hop_limit == 1
    error_message = "containers must not reach the instance's credentials (hop limit 1)"
  }
  assert {
    condition     = one(aws_instance.this.root_block_device).encrypted == true
    error_message = "the root disk must be encrypted"
  }
  assert {
    condition     = aws_instance.this.instance_type == "t3.micro"
    error_message = "the default size should be t3.micro"
  }
  assert {
    condition     = aws_instance.this.user_data_replace_on_change == true
    error_message = "a new build must replace the instance so user_data runs again"
  }
}

run "role_can_only_use_the_backup_bucket" {
  command = plan
  assert {
    condition = alltrue([for s in jsondecode(aws_iam_role_policy.backups.policy).Statement :
    contains(["arn:aws:s3:::linkly-course-backups-123", "arn:aws:s3:::linkly-course-backups-123/*"], s.Resource)])
    error_message = "every statement must name only the backup bucket"
  }
}

run "first_boot_starts_linkly" {
  command = plan
  assert {
    condition     = strcontains(output.user_data, "install-docker.sh") && strcontains(output.user_data, "COMPOSE_VERSION=")
    error_message = "user_data must install Docker and Compose"
  }
  assert {
    condition     = strcontains(output.user_data, "build: !reset null") && strcontains(output.user_data, "postgres:16-alpine")
    error_message = "user_data must carry compose.yaml and compose.ghcr.yaml"
  }
  assert {
    condition     = strcontains(output.user_data, "LINKLY_IMAGES=ghcr.io/learner\nLINKLY_TAG=sha-abc1234\n")
    error_message = "user_data must run the chosen images and build"
  }
  assert {
    # At the start of a line: compose.ghcr.yaml's own header comment mentions the same command.
    condition     = can(regex("(?m)^docker compose -f compose.yaml -f compose.ghcr.yaml up -d --wait$", output.user_data))
    error_message = "user_data must start Linkly"
  }
}

run "settings_survive_for_later_compose_commands" {
  command = plan
  assert {
    condition     = can(regex("(?m)^cat > /opt/linkly/[.]env <<", output.user_data)) && strcontains(output.user_data, "LINKLY_IMAGES=ghcr.io/learner")
    error_message = "user_data must write /opt/linkly/.env, so docker compose works on the server after first boot (backups, logs)"
  }
}

run "iam_names_match_module_6_cleanup" {
  command = plan
  assert {
    condition     = aws_iam_role.this.name == "linkly-course-ec2" && aws_iam_instance_profile.this.name == "linkly-course-ec2"
    error_message = "the role and instance profile must be named linkly-course-ec2, which cleanup.sh looks for"
  }
}
