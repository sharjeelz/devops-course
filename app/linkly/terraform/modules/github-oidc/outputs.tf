output "role_arn" {
  description = "Put it in the repository variable AWS_PLAN_ROLE_ARN."
  value       = aws_iam_role.plan.arn
}
