# Linkly's backup bucket (module 7): Module 6, lesson 5 as code. Private, versioned, encrypted, and
# old versions expire on their own so storage doesn't grow forever.
resource "aws_s3_bucket" "this" {
  bucket_prefix = "${var.name_prefix}-" # AWS adds a unique suffix: bucket names are global
  force_destroy = var.force_destroy     # true: terraform destroy also deletes the backups in it
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket                  = aws_s3_bucket.this.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket     = aws_s3_bucket.this.id
  depends_on = [aws_s3_bucket_versioning.this]

  rule {
    id     = "expire-old-versions"
    status = "Enabled"
    filter {}
    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }

  rule {
    id     = "expire-old-backups"
    status = "Enabled"
    filter {
      prefix = "linkly-"
    }
    expiration {
      days = 90
    }
  }
}
