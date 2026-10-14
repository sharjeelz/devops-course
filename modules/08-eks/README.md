# Production on EKS

> **You need:** Modules 4, 5 and 7 · **Time:** ~12 hours · **Start from:** `checkpoint/08-eks`

Linkly has run on your laptop (kind) and on one server (EC2). This module runs it the way a
company would: on **EKS**, AWS's managed Kubernetes, with the database on **RDS**, its password in
**AWS Secrets Manager** (never in Git, never in Helm values), **HTTPS** with a real certificate,
**autoscaling**, **Argo CD** deploying every build, and CI that can **plan Terraform with no stored
AWS keys**.

> **Costs: this is the expensive module. Read this before lesson 2.**
>
> | While it exists | Roughly |
> |---|---|
> | EKS control plane | $0.10/hour |
> | 2 × t3.medium nodes | $0.08/hour (about 60% less with `node_capacity_type = "SPOT"`) |
> | RDS db.t4g.micro + 20 GB | $0.02/hour |
> | Load balancer + public IPv4 addresses | $0.05/hour |
> | **Total** | **about $0.25 per hour, about $6 a day** |
>
> So: **rehearse everything for free first (lesson 1)**, then do lessons 2–6 in one or two
> sittings, and tear down at the end of each with `AWS_REGION=<region> app/linkly/eks/teardown.sh`.
> (Not plain `terraform destroy`: Kubernetes made Linkly's load balancer, so Terraform can't
> remove it, and it would block deleting the VPC while it keeps billing. The script removes it first.)
>
> A day of forgetting costs ~$6; a month, ~$180. Your Module 6 budget alert will email you, but don't rely on it. Prices vary a little by
> region; check the [EKS](https://aws.amazon.com/eks/pricing/) and
> [RDS](https://aws.amazon.com/rds/postgresql/pricing/) pricing pages.

## Install

- **kubectl, Helm, kind** from Modules 3–4; **Terraform** and **AWS CLI** (signed in) from Modules 6–7.
- **A domain name you control** for lesson 5 (any registrar; ~$10/year). No domain? Lesson 5
  shows how to run without HTTPS on the load balancer's own address.

## Before you start

```bash
git switch main && git pull
git checkout origin/checkpoint/09-ansible -- app/linkly tools .github
```

(No checkpoint branches in your fork? Use `upstream/` after
`git remote add upstream https://github.com/sharjeelz/devops-course.git && git fetch upstream`.)

## Lessons

1. [Rehearse on kind](01-rehearse-on-kind.md): the whole production setup, free, on your laptop
2. [EKS with Terraform](02-eks-with-terraform.md): a cluster, its nodes, and who may use it
3. [RDS and secrets](03-rds-and-secrets.md): a managed database, and a password nobody types
4. [Deploy with Argo CD](04-deploy-with-argo-cd.md): add-ons, a load balancer, GitOps on EKS
5. [HTTPS](05-https.md): DNS, Let's Encrypt and cert-manager
6. [Autoscaling](06-autoscaling.md): more pods when busy, more nodes when full
7. [CI with OIDC](07-ci-with-oidc.md): terraform plan from GitHub Actions without keys
8. [Landscape: running containers on AWS](08-landscape.md): ECS, Fargate, App Runner, EKS Auto Mode

By the end, `checkpoint/09-ansible` holds Linkly with everything from this module: where Module 9 starts.
