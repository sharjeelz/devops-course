mock_provider "aws" {}

run "state_bucket_is_private_versioned_encrypted_and_kept" {
  command = apply
  assert {
    condition     = one(aws_s3_bucket_versioning.state.versioning_configuration).status == "Enabled"
    error_message = "state history must be kept (versioning)"
  }
  assert {
    condition = (aws_s3_bucket_public_access_block.state.block_public_acls && aws_s3_bucket_public_access_block.state.ignore_public_acls
    && aws_s3_bucket_public_access_block.state.block_public_policy && aws_s3_bucket_public_access_block.state.restrict_public_buckets)
    error_message = "the state bucket must be private"
  }
  assert {
    condition     = aws_s3_bucket.state.force_destroy == false
    error_message = "the state bucket must never be force-destroyed"
  }
  # prevent_destroy can't be observed by terraform test; tools/check-terraform.sh greps for it.
}
