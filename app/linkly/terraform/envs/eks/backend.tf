# State lives in S3 (the bucket from ../../bootstrap), locked while someone runs plan or apply.
# The bucket and region are given at init:
#   terraform init -backend-config="bucket=<state bucket>" -backend-config="region=<region>"
terraform {
  backend "s3" {
    key          = "linkly/eks/terraform.tfstate"
    use_lockfile = true
    encrypt      = true
  }
}
