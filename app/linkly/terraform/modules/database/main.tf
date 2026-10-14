# Linkly's database on RDS (module 8): Postgres in private subnets, reachable only from the EKS
# cluster, encrypted, with a password RDS generates and keeps in AWS Secrets Manager (and rotates).
resource "aws_db_subnet_group" "this" {
  name       = var.name
  subnet_ids = var.subnet_ids # private: no route to or from the internet
}

resource "aws_security_group" "this" {
  name        = "${var.name}-db"
  description = "Linkly course - Postgres from the EKS cluster only"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.name}-db" }
}

resource "aws_vpc_security_group_ingress_rule" "postgres" {
  security_group_id            = aws_security_group.this.id
  referenced_security_group_id = var.allowed_security_group_id # the cluster's nodes, not an address range
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}

resource "aws_db_instance" "this" {
  identifier     = var.name
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class
  multi_az       = var.multi_az # a standby in a second AZ: production yes, a course no (it doubles the cost)

  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  db_name                     = "linkly"
  username                    = "linkly"
  manage_master_user_password = true # RDS makes the password and stores it in Secrets Manager

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]
  publicly_accessible    = false

  backup_retention_period = 1                       # daily automated backups, kept one day (a course)
  skip_final_snapshot     = var.skip_final_snapshot # true: destroy without a last snapshot
  deletion_protection     = false
  apply_immediately       = true
}
