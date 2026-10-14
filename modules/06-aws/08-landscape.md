# Landscape: other clouds

> **You need:** Lessons 1–7 · **Time:** ~30 min · **Cost:** free · **Start from:** `checkpoint/06-aws`

## Why this matters

AWS is the biggest cloud, but your next job may run on Azure or Google Cloud. The good news: the
building blocks you just used exist everywhere under other names, and the skills (networks,
identities, least privilege, tagging, clean-up) carry over almost one to one.

## Concept

| What you used | AWS | Azure | Google Cloud |
|---|---|---|---|
| People and permissions | IAM, IAM Identity Center | Microsoft Entra ID, Azure RBAC | Cloud IAM |
| Private network | VPC (per region) | Virtual Network (VNet) | VPC (global, subnets per region) |
| Virtual machines | EC2 | Virtual Machines | Compute Engine |
| Object storage | S3 | Blob Storage | Cloud Storage |
| Container registry | ECR | Azure Container Registry | Artifact Registry |
| Managed Kubernetes | EKS | AKS | GKE |
| Monitoring | CloudWatch | Azure Monitor | Cloud Monitoring |
| Infrastructure as code (native) | CloudFormation | Bicep / ARM | Deployment Manager / Infrastructure Manager |

**Real differences worth knowing:**

- **Azure resource groups:** every resource sits in a resource group, and deleting the group
  deletes everything in it. It's a clean-up model AWS doesn't have (AWS uses tags).
- **Google Cloud projects** are the main boundary for billing, IAM and quotas, and a GCP VPC is
  *global*, with subnets per region.
- **Identity:** Azure is built around Entra ID (the old Azure AD), which companies often already
  use for Office 365.
- **Multi-cloud** sounds like freedom, but every cloud's managed services differ. Most teams pick
  one main cloud and stay portable through containers, Kubernetes and Terraform (Module 7).

## Example

What Linkly's setup looks like as Azure CLI commands, for comparison only (not run):

```text
az group create --name linkly-course --location westeurope
az network vnet create --resource-group linkly-course --name linkly --address-prefix 10.0.0.0/16 \
  --subnet-name public --subnet-prefix 10.0.1.0/24
az vm create --resource-group linkly-course --name linkly --image Ubuntu2404 --size Standard_B1s \
  --vnet-name linkly --subnet public --generate-ssh-keys
az group delete --name linkly-course        # clean-up: one command
```

## Lab

- [ ] Map Linkly's AWS setup to Azure or Google Cloud
- [ ] Name one real difference between AWS and the cloud you chose
- [ ] Explain why many teams stay on one main cloud

## Check yourself

1. How does Azure make "delete everything from this course" easier than AWS?

<details><summary>Answer</summary>

Every resource belongs to a resource group; deleting the group deletes all of it. In AWS you
find things by tags and delete them in dependency order yourself.

</details>

2. What carries over between clouds, and what doesn't?

<details><summary>Answer</summary>

Concepts carry over: networks and subnets, identities and least privilege, VMs, object storage,
registries, tags, budgets. Exact services, limits, prices and APIs don't; that's where tools like
Terraform and Kubernetes help.

</details>
