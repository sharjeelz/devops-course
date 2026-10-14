# Terraform

> **You need:** Module 6 · **Time:** ~10 hours · **Start from:** `checkpoint/07-terraform`

In Module 6 you built Linkly's AWS setup by hand: about thirty commands, IDs copied between
terminals, an order you had to remember, and a clean-up script to find it all again. In this module
the same setup becomes **code**: a description of what should exist, which Terraform compares with
what *does* exist and then makes it so. One command builds it, one destroys it, and a pull request
shows exactly what would change before anything does.

> **Costs: the same as Module 6.** `terraform apply` creates a `t3.micro` with a public IPv4
> address (about $0.02 per hour together), a small EBS disk, and two S3 buckets (cents).
> `terraform destroy` removes the environment; the state bucket stays (on purpose) until you delete
> it at the end of the course. Your Module 6 budget alert keeps watching. Everything is tagged
> `Project=linkly-course`, so Module 6's `cleanup.sh` finds it too.

## Install

- **Terraform 1.16** from HashiCorp's [install page](https://developer.hashicorp.com/terraform/install)
  (apt repository on Linux/WSL, or the zip; check the `SHA256SUMS` if you download by hand).
  Check with `terraform version`.
- Signed in to AWS as in Module 6: `aws sso login --profile linkly`, then
  `export AWS_PROFILE=linkly AWS_REGION=eu-central-1`. Terraform uses the same credentials.

## Before you start

```bash
git switch main && git pull
git checkout origin/checkpoint/08-eks -- app/linkly tools .github
```

(No checkpoint branches in your fork? Use `upstream/` after
`git remote add upstream https://github.com/sharjeelz/devops-course.git && git fetch upstream`.)

If Module 6's resources still exist, remove them first (`app/linkly/aws/cleanup.sh`), so the two
setups don't get confused.

## Lessons

1. [Why infrastructure as code](01-why-infrastructure-as-code.md): from thirty commands to one description
2. [Your first configuration](02-first-configuration.md): providers, resources, plan, apply, destroy
3. [State](03-state.md): how Terraform remembers, and keeping that memory safe in S3
4. [Modules](04-modules.md): reusable building blocks
5. [Linkly as code](05-linkly-as-code.md): the whole of Module 6 in one apply
6. [Testing and CI](06-testing-and-ci.md): checking infrastructure without an AWS account
7. [Landscape: IaC tools](07-landscape.md): OpenTofu, Pulumi, CloudFormation and friends

By the end, `checkpoint/08-eks` holds Linkly with its Terraform: where Module 8 starts.
