mock_provider "aws" {}

variables {
  name_prefix   = "linkly-course-backups"
  force_destroy = true
}

run "private_versioned_encrypted" {
  command = apply
  assert {
    condition = (aws_s3_bucket_public_access_block.this.block_public_acls && aws_s3_bucket_public_access_block.this.ignore_public_acls
    && aws_s3_bucket_public_access_block.this.block_public_policy && aws_s3_bucket_public_access_block.this.restrict_public_buckets)
    error_message = "all four public access blocks must be on"
  }
  assert {
    condition     = one(aws_s3_bucket_versioning.this.versioning_configuration).status == "Enabled"
    error_message = "versioning must be on"
  }
  assert {
    condition     = one(one(aws_s3_bucket_server_side_encryption_configuration.this.rule).apply_server_side_encryption_by_default).sse_algorithm == "AES256"
    error_message = "objects must be encrypted at rest"
  }
  assert {
    condition     = aws_s3_bucket.this.force_destroy == true
    error_message = "force_destroy should follow the variable"
  }
}

run "old_versions_expire" {
  command = plan
  assert {
    condition     = contains([for r in aws_s3_bucket_lifecycle_configuration.this.rule : r.id], "expire-old-versions")
    error_message = "noncurrent versions must expire"
  }
}

run "bucket_names_are_checked" {
  command = plan
  variables {
    name_prefix = "Linkly_Course"
  }
  expect_failures = [var.name_prefix]
}
