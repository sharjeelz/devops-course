mock_provider "aws" {
  mock_resource "aws_db_instance" {
    defaults = {
      address            = "linkly-course.abc123.eu-central-1.rds.amazonaws.com"
      master_user_secret = [{ secret_arn = "arn:aws:secretsmanager:eu-central-1:123456789012:secret:rds!db-123-AbCdEf", kms_key_id = "k", secret_status = "active" }]
    }
  }
}

variables {
  name                      = "linkly-course"
  vpc_id                    = "vpc-0aaa"
  subnet_ids                = ["subnet-0p1", "subnet-0p2"]
  allowed_security_group_id = "sg-0cluster"
}

run "private_encrypted_small_postgres" {
  command = plan
  assert {
    condition     = aws_db_instance.this.engine == "postgres" && startswith(aws_db_instance.this.engine_version, "16")
    error_message = "Postgres 16, like the rest of the course"
  }
  assert {
    condition     = aws_db_instance.this.instance_class == "db.t4g.micro" && aws_db_instance.this.multi_az == false
    error_message = "the smallest instance, one AZ, by default"
  }
  assert {
    condition     = aws_db_instance.this.publicly_accessible == false && aws_db_instance.this.storage_encrypted
    error_message = "never public, always encrypted"
  }
  assert {
    condition     = tolist(aws_db_subnet_group.this.subnet_ids) == tolist(["subnet-0p1", "subnet-0p2"])
    error_message = "in the private subnets given"
  }
}

run "password_managed_by_aws" {
  command = plan
  assert {
    condition     = aws_db_instance.this.manage_master_user_password == true && aws_db_instance.this.password == null
    error_message = "RDS generates the password and keeps it in Secrets Manager: none in code or state"
  }
}

run "only_the_cluster_reaches_it" {
  command = plan
  assert {
    condition     = aws_vpc_security_group_ingress_rule.postgres.referenced_security_group_id == "sg-0cluster" && aws_vpc_security_group_ingress_rule.postgres.from_port == 5432 && aws_vpc_security_group_ingress_rule.postgres.cidr_ipv4 == null
    error_message = "5432 open only to the cluster's security group, no address ranges"
  }
}

run "outputs_for_the_chart" {
  command = apply
  assert {
    condition     = output.host == "linkly-course.abc123.eu-central-1.rds.amazonaws.com"
    error_message = "the endpoint goes to externalDatabase.host"
  }
  assert {
    condition     = startswith(output.secret_arn, "arn:aws:secretsmanager:")
    error_message = "the secret's ARN goes to externalDatabase.externalSecret.remoteKey"
  }
}
