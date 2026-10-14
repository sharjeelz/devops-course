mock_provider "aws" {}

variables {
  name                   = "linkly-course"
  subnet_ids             = ["subnet-0aaa", "subnet-0bbb"]
  endpoint_allowed_cidrs = ["203.0.113.10/32"]
  readable_secret_arns   = ["arn:aws:secretsmanager:eu-central-1:123456789012:secret:rds!db-123-AbCdEf"]
}

run "cluster" {
  command = plan
  assert {
    condition     = aws_eks_cluster.this.version == "1.35"
    error_message = "pinned Kubernetes version expected"
  }
  assert {
    condition     = one(aws_eks_cluster.this.access_config).authentication_mode == "API" && one(aws_eks_cluster.this.access_config).bootstrap_cluster_creator_admin_permissions
    error_message = "access entries (API mode), with the creator as admin"
  }
  assert {
    condition     = tolist(one(aws_eks_cluster.this.vpc_config).public_access_cidrs) == tolist(["203.0.113.10/32"])
    error_message = "the API endpoint must be reachable only from the allowed addresses"
  }
}

run "nodes" {
  command = plan
  assert {
    condition     = one(aws_eks_node_group.this.scaling_config).min_size == 2 && one(aws_eks_node_group.this.scaling_config).max_size == 3
    error_message = "2 to 3 nodes by default"
  }
  assert {
    condition     = tolist(aws_eks_node_group.this.instance_types) == tolist(["t3.medium"])
    error_message = "t3.medium nodes by default"
  }
  assert {
    condition = toset([for a in aws_iam_role_policy_attachment.node : a.policy_arn]) == toset([
      "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
      "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
      "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    ])
    error_message = "nodes get exactly the three standard policies"
  }
}

run "addons" {
  command = plan
  assert {
    condition     = toset(keys(aws_eks_addon.this)) == toset(["vpc-cni", "kube-proxy", "coredns", "eks-pod-identity-agent"])
    error_message = "the four core add-ons, including the Pod Identity agent"
  }
}

run "external_secrets_reads_only_its_secret" {
  command = plan
  assert {
    condition     = aws_eks_pod_identity_association.external_secrets.namespace == "external-secrets" && aws_eks_pod_identity_association.external_secrets.service_account == "external-secrets"
    error_message = "the role goes to External Secrets' service account"
  }
  assert {
    condition = alltrue([for s in jsondecode(aws_iam_role_policy.external_secrets.policy).Statement :
    s.Resource == ["arn:aws:secretsmanager:eu-central-1:123456789012:secret:rds!db-123-AbCdEf"]])
    error_message = "External Secrets may read only the given secrets"
  }
  assert {
    condition     = toset(one(jsondecode(aws_iam_role_policy.external_secrets.policy).Statement).Action) == toset(["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"])
    error_message = "read-only access"
  }
  assert {
    condition     = one(jsondecode(aws_iam_role.external_secrets.assume_role_policy).Statement).Principal.Service == "pods.eks.amazonaws.com"
    error_message = "trusted by EKS Pod Identity"
  }
}

run "refuses_an_open_api_endpoint" {
  command = plan
  variables {
    endpoint_allowed_cidrs = ["0.0.0.0/0"]
  }
  expect_failures = [var.endpoint_allowed_cidrs]
}
