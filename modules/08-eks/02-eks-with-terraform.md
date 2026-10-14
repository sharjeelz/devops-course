# EKS with Terraform

> **You need:** Lesson 1, Module 7's state bucket · **Time:** ~75 min · **Cost:** about $0.25/hour from `apply` until `destroy` · **Start from:** `checkpoint/08-eks`

## Why this matters

EKS runs the Kubernetes control plane for you (API server, etcd, upgrades, high availability
across zones), so you look after your workloads, not etcd backups. But a cluster still needs a
network, nodes, IAM roles and add-ons, and you want all of it as code you can destroy at night.

## Concept

- **Control plane:** managed by AWS, billed hourly. You choose the Kubernetes version (1.35 here)
  and who can reach its API: `public_access_cidrs` limits `kubectl` to your own address.
- **Access entries** (`authentication_mode = "API"`): who may use the cluster is an AWS API
  object, not the old `aws-auth` ConfigMap. `bootstrap_cluster_creator_admin_permissions` makes
  whoever ran `apply` an admin.
- **Managed node group:** EC2 instances that EKS creates, joins and upgrades one at a time
  (`max_unavailable = 1`, respecting PodDisruptionBudgets). Nodes have an IAM role with three
  standard policies: join the cluster, run the VPC CNI, pull images.
- **VPC CNI:** pods get real VPC IP addresses. That's why a node type has a pod limit (a
  t3.medium takes 17 pods), and why `t3.small` runs out of room with the add-ons.
- **Add-ons:** `vpc-cni`, `kube-proxy`, `coredns` and `eks-pod-identity-agent`, managed by EKS.
- **The network:** public subnets for nodes and load balancers (tagged
  `kubernetes.io/role/elb = 1`, so Kubernetes knows where internet load balancers go) and private
  subnets with **no route out at all** for the database. There's no NAT gateway (it would add
  ~$0.045/hour), so nodes have public IPs but their security group admits nothing from the internet.
  A production VPC would put nodes in private subnets behind NAT; the trade-off is cost.

The code: `app/linkly/terraform/modules/eks` (and `network`, `database`), put together in
`app/linkly/terraform/envs/eks`.

## Example

```bash
cd app/linkly/terraform/envs/eks
cp terraform.tfvars.example terraform.tfvars        # your /32, your region
terraform init -backend-config="bucket=<state bucket>" -backend-config="region=$AWS_REGION"
terraform plan                                      # 31 to add
terraform apply                                     # ~15 minutes: the control plane is the slow part
$(terraform output -raw kubeconfig_command)         # points kubectl at the new cluster
kubectl get nodes -o wide                           # two nodes, in two zones
kubectl get pods -A                                 # the add-ons
```

(The `terraform test` files in each module run all of this against a mock AWS: `tools/check-terraform.sh`.)

## Lab

- [ ] Read the eks module and name what each resource is for
- [ ] Apply the EKS environment and connect kubectl
- [ ] Find your two nodes and the zones they're in
- [ ] Show that the API is reachable only from your address
- [ ] Explain why the database subnets have no route table entries

## Check yourself

1. Your IP changes and `kubectl` times out. Why, and what's the fix?

<details><summary>Answer</summary>

The API endpoint only accepts `public_access_cidrs`, your old /32. Update `allowed_cidr` in
terraform.tfvars and `terraform apply`.

</details>

2. Why can't you just pick the smallest instance type for nodes?

<details><summary>Answer</summary>

With the VPC CNI, every pod takes an IP from the node's network interfaces, and small types have
few. The add-ons alone take several pods per node, so a t3.small fills up before Linkly fits.

</details>

## Clean up

If you stop here: `terraform destroy` (about 10 minutes; nothing made by Kubernetes exists yet).
Otherwise keep it for lessons 3–6. From lesson 4 on, always tear down with
`AWS_REGION=<region> app/linkly/eks/teardown.sh`, which removes Kubernetes' load balancer first.
