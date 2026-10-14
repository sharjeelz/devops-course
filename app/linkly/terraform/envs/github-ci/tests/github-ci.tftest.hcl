mock_provider "aws" {
  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::123456789012:role/linkly-course-github-plan" }
  }
}

variables {
  repository   = "learner/devops-course"
  state_bucket = "linkly-course-tfstate-123"
}

run "outputs_the_role_for_the_repository_variable" {
  command = apply
  assert {
    condition     = output.role_arn == "arn:aws:iam::123456789012:role/linkly-course-github-plan"
    error_message = "role_arn output expected"
  }
}
