# The role GitHub Actions uses to run terraform plan (module 8, lesson 7). Apply it once, then put
# the role_arn output in your repository's variables as AWS_PLAN_ROLE_ARN.
module "github_oidc" {
  source           = "../../modules/github-oidc"
  repository       = var.repository
  state_bucket_arn = "arn:aws:s3:::${var.state_bucket}"
}

output "role_arn" {
  value = module.github_oidc.role_arn
}
