# Lets GitHub Actions run terraform plan in your AWS account with no stored keys (module 8).
# GitHub signs a short-lived token for each workflow run ("this is repo X, branch main"); AWS checks
# the signature and the claims, then hands out credentials for this role for about an hour.
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  # No thumbprint: AWS trusts GitHub's issuer through its own certificate store.
}

resource "aws_iam_role" "plan" {
  name                 = "${var.name}-plan"
  max_session_duration = 3600
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = { "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com" }
        StringLike = { "token.actions.githubusercontent.com:sub" = [
          "repo:${var.repository}:ref:refs/heads/main", # pushes to main
          "repo:${var.repository}:pull_request",        # pull requests (forks' PRs get no token)
        ] }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "read_only" {
  role       = aws_iam_role.plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess" # see everything, change nothing
}

# terraform plan reads the state and holds a lock file next to it while it runs.
resource "aws_iam_role_policy" "state" {
  name = "terraform-state"
  role = aws_iam_role.plan.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = "s3:ListBucket", Resource = var.state_bucket_arn },
      { Effect = "Allow", Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"], Resource = "${var.state_bucket_arn}/*" },
    ]
  })
}
