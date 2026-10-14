# Linkly's server (module 7): Module 6, lessons 3–5 as code. One EC2 instance that installs Docker
# and starts Linkly from your GHCR images on first boot, reachable only from one address, with a
# role that can use the backup bucket and nothing else.
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_key_pair" "this" {
  key_name   = var.name
  public_key = var.ssh_public_key # your public key: the private one never leaves your machine
}

resource "aws_security_group" "this" {
  name        = var.name
  description = "Linkly course - SSH and web from one address"
  vpc_id      = var.vpc_id
  tags        = { Name = var.name }
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.this.id
  cidr_ipv4         = var.allowed_cidr
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "web" {
  security_group_id = aws_security_group.this.id
  cidr_ipv4         = var.allowed_cidr
  from_port         = 8080
  to_port           = 8080
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.this.id
  cidr_ipv4         = "0.0.0.0/0" # out to GitHub (images), AWS APIs and package mirrors
  ip_protocol       = "-1"
}

resource "aws_iam_role" "this" {
  name = "${var.name}-ec2" # linkly-course-ec2: the name Module 6's cleanup.sh looks for
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}

resource "aws_iam_role_policy" "backups" {
  name = "${var.name}-backups"
  role = aws_iam_role.this.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Sid = "ReadWriteBackups", Effect = "Allow", Action = ["s3:PutObject", "s3:GetObject"], Resource = "${var.backup_bucket_arn}/*" },
      { Sid = "ListBackups", Effect = "Allow", Action = "s3:ListBucket", Resource = var.backup_bucket_arn },
    ]
  })
}

resource "aws_iam_instance_profile" "this" {
  name = "${var.name}-ec2"
  role = aws_iam_role.this.name
}

resource "aws_instance" "this" {
  ami                    = data.aws_ssm_parameter.al2023.insecure_value
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.this.id]
  key_name               = aws_key_pair.this.key_name
  iam_instance_profile   = aws_iam_instance_profile.this.name

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2 only
    http_put_response_hop_limit = 1          # containers can't reach the instance's credentials
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 8
    encrypted   = true
  }

  user_data                   = var.user_data_enabled ? local.user_data : null
  user_data_replace_on_change = true # a new image tag = a fresh instance that starts it from scratch

  tags = { Name = var.name }

  lifecycle {
    # The AMI parameter always points at the newest AL2023, released every few weeks. Without this,
    # a later apply with no code change would replace the server, and Linkly's data on its disk.
    # A replacement for another reason (a new tag) still gets the newest AMI.
    ignore_changes = [ami]
  }
}

locals {
  user_data = templatefile("${path.module}/user-data.sh.tftpl", {
    install_docker = file("${path.module}/../../../aws/install-docker.sh")
    compose        = file("${path.module}/../../../compose.yaml")
    compose_ghcr   = file("${path.module}/../../../compose.ghcr.yaml")
    linkly_images  = var.linkly_images
    linkly_tag     = var.linkly_tag
  })
}
