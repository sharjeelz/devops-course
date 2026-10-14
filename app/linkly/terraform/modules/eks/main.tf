# An EKS cluster for Linkly (module 8), from plain resources so every part is visible: the control
# plane and its role, a managed node group and its role, the core add-ons, and an IAM role that
# External Secrets gets through EKS Pod Identity. (terraform-aws-modules/eks wraps all of this.)
locals {
  addons = ["vpc-cni", "kube-proxy", "coredns", "eks-pod-identity-agent"]
}

# --- control plane ---------------------------------------------------------------------------
resource "aws_iam_role" "cluster" {
  name = "${var.name}-eks-cluster"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "eks.amazonaws.com" }, Action = ["sts:AssumeRole", "sts:TagSession"] }]
  })
}

resource "aws_iam_role_policy_attachment" "cluster" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_eks_cluster" "this" {
  name     = var.name
  version  = var.kubernetes_version
  role_arn = aws_iam_role.cluster.arn

  access_config {
    authentication_mode                         = "API" # who may use the cluster: EKS access entries, not a ConfigMap
    bootstrap_cluster_creator_admin_permissions = true  # whoever runs terraform apply is admin
  }

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_public_access  = true
    endpoint_private_access = true
    public_access_cidrs     = var.endpoint_allowed_cidrs # kubectl only from your address
  }

  depends_on = [aws_iam_role_policy_attachment.cluster]
}

# --- nodes -----------------------------------------------------------------------------------
resource "aws_iam_role" "node" {
  name = "${var.name}-eks-node"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}

resource "aws_iam_role_policy_attachment" "node" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
  ])
  role       = aws_iam_role.node.name
  policy_arn = each.value
}

resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.name}-default"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.subnet_ids
  instance_types  = var.node_instance_types
  capacity_type   = var.node_capacity_type

  scaling_config {
    min_size     = var.node_min
    desired_size = var.node_min
    max_size     = var.node_max
  }

  update_config {
    max_unavailable = 1 # upgrades replace one node at a time (PodDisruptionBudgets are respected)
  }

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size] # a cluster autoscaler may change it
  }

  depends_on = [aws_iam_role_policy_attachment.node]
}

# --- add-ons ---------------------------------------------------------------------------------
resource "aws_eks_addon" "this" {
  for_each     = toset(local.addons)
  cluster_name = aws_eks_cluster.this.name
  addon_name   = each.value # no version: EKS picks the default for the cluster's Kubernetes version
  depends_on   = [aws_eks_node_group.this]
}

# --- External Secrets' AWS identity (EKS Pod Identity) ---------------------------------------
resource "aws_iam_role" "external_secrets" {
  name = "${var.name}-external-secrets"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "pods.eks.amazonaws.com" }, Action = ["sts:AssumeRole", "sts:TagSession"] }]
  })
}

resource "aws_iam_role_policy" "external_secrets" {
  name = "read-linkly-secrets"
  role = aws_iam_role.external_secrets.id
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"], Resource = var.readable_secret_arns }]
  })
}

resource "aws_eks_pod_identity_association" "external_secrets" {
  cluster_name    = aws_eks_cluster.this.name
  namespace       = "external-secrets" # where app/linkly/eks/addons.sh installs it
  service_account = "external-secrets"
  role_arn        = aws_iam_role.external_secrets.arn
}
