output "cluster_name" {
  value = aws_eks_cluster.this.name
}

output "cluster_security_group_id" {
  description = "EKS attaches it to the nodes: the database lets this group in."
  value       = one(aws_eks_cluster.this.vpc_config).cluster_security_group_id
}
