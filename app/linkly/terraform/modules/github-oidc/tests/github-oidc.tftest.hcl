mock_provider "aws" {}

variables {
  repository       = "learner/devops-course"
  state_bucket_arn = "arn:aws:s3:::linkly-course-tfstate-123"
}

run "trusts_only_this_repository" {
  command = apply
  assert {
    condition     = aws_iam_openid_connect_provider.github.url == "https://token.actions.githubusercontent.com" && tolist(aws_iam_openid_connect_provider.github.client_id_list) == tolist(["sts.amazonaws.com"])
    error_message = "GitHub's OIDC issuer, for AWS STS"
  }
  assert {
    condition     = one(jsondecode(aws_iam_role.plan.assume_role_policy).Statement).Condition.StringEquals["token.actions.githubusercontent.com:aud"] == "sts.amazonaws.com"
    error_message = "tokens must be meant for AWS"
  }
  assert {
    condition = toset(one(jsondecode(aws_iam_role.plan.assume_role_policy).Statement).Condition.StringLike["token.actions.githubusercontent.com:sub"]) == toset([
      "repo:learner/devops-course:ref:refs/heads/main",
      "repo:learner/devops-course:pull_request",
    ])
    error_message = "only this repository's main branch and its pull requests"
  }
}

run "can_read_and_plan_but_not_change" {
  command = apply
  assert {
    condition     = aws_iam_role_policy_attachment.read_only.policy_arn == "arn:aws:iam::aws:policy/ReadOnlyAccess"
    error_message = "read-only access to the account (enough for terraform plan)"
  }
  assert {
    condition     = alltrue([for s in jsondecode(aws_iam_role_policy.state.policy).Statement : alltrue([for r in flatten([s.Resource]) : startswith(r, "arn:aws:s3:::linkly-course-tfstate-123")])])
    error_message = "write access only to the state bucket (for the lock file)"
  }
  assert {
    condition     = contains(flatten([for s in jsondecode(aws_iam_role_policy.state.policy).Statement : s.Action]), "s3:DeleteObject")
    error_message = "plan takes and releases a lock file: it must be able to delete it"
  }
  assert {
    condition = alltrue([for s in jsondecode(aws_iam_role_policy.state.policy).Statement :
    alltrue([for r in flatten([s.Resource]) : endswith(r, ".tflock")]) if length(setintersection(toset(flatten([s.Action])), toset(["s3:PutObject", "s3:DeleteObject"]))) > 0])
    error_message = "it may write and delete only lock files, never the state itself"
  }
}

run "refuses_a_wildcard_repository" {
  command = plan
  variables {
    repository = "learner/*"
  }
  expect_failures = [var.repository]
}
