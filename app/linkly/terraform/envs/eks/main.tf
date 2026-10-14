# Linkly's production-style environment on AWS (module 8): a VPC with public subnets (nodes, load
# balancer) and private ones (database), an EKS cluster, and Postgres on RDS.
# terraform apply → a cluster to deploy Linkly onto (lessons 3-6); terraform destroy → all gone.
# Costs while it exists: about $0.20 per hour (see the module README). Destroy it when you're done.
module "network" {
  source             = "../../modules/network"
  name               = "linkly-course-eks"
  cidr               = "10.1.0.0/16" # not 10.0: Module 7's VPC may still exist
  private_subnets    = true
  public_subnet_tags = { "kubernetes.io/role/elb" = "1" } # where Kubernetes puts internet load balancers
}

module "eks" {
  source                 = "../../modules/eks"
  name                   = "linkly-course"
  kubernetes_version     = var.kubernetes_version
  subnet_ids             = module.network.public_subnet_ids # no NAT gateway: nodes get public IPs, but accept nothing from the internet
  endpoint_allowed_cidrs = [var.allowed_cidr]
  node_capacity_type     = var.node_capacity_type
  readable_secret_arns   = [module.database.secret_arn]
}

module "database" {
  source                    = "../../modules/database"
  name                      = "linkly-course-eks"
  vpc_id                    = module.network.vpc_id
  subnet_ids                = module.network.private_subnet_ids
  allowed_security_group_id = module.eks.cluster_security_group_id
}
