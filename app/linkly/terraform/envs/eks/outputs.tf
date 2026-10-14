output "kubeconfig_command" {
  description = "Run it to point kubectl at the cluster."
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.region}"
}

output "db_host" {
  value = module.database.host
}

output "db_secret_arn" {
  value = module.database.secret_arn
}
