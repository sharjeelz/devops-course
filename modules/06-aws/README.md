# AWS Foundations

> **You need:** Modules 1–2 (Docker, and your pipeline publishing images to GHCR) · **Time:** ~10 hours · **Start from:** `checkpoint/06-aws`

Everything so far ran on your laptop. Now Linkly moves to the cloud. This module covers the AWS
building blocks every later module leans on: a safe account, identities and permissions,
networks, virtual machines, storage and a container registry. It ends with you deploying Linkly
on one EC2 instance **by hand, on purpose**, so that in Module 7 you can feel what Terraform takes away.

> **This module costs real money. Read this first.**
>
> | What | Roughly | When it stops |
> |---|---|---|
> | One `t3.micro` instance | ~$0.01 per hour | when you terminate it |
> | Its public IPv4 address | ~$0.005 per hour | when the instance is gone |
> | Its 8 GB disk (EBS) | ~$0.001 per hour | when the instance is gone |
> | S3 and ECR storage | a few cents a month | when you delete them |
>
> Done in a day and cleaned up, the whole module should cost **well under $1**. New AWS
> accounts get Free Tier credits; check AWS's current Free Tier terms for your account.
> - **Lesson 1's first lab is a budget alert**, so AWS emails you before costs surprise you.
> - **Tag everything** with `Project=linkly-course` (every command here does).
> - **When you're done for the day**, run `app/linkly/aws/cleanup.sh` (lesson 7). It deletes
>   everything this module creates, in the right order, and it's safe to run twice.

## Install

- **AWS CLI v2:** follow AWS's "Install or update to the latest version of the AWS CLI" guide
  for your system (on WSL/Ubuntu, the Linux x86 zip). Check with `aws --version`.
- An SSH client (already in WSL and macOS).

## Before you start

Bring in this module's files (the installer, Compose overlay, policies and the clean-up script):

```bash
git switch main && git pull
git checkout origin/checkpoint/07-terraform -- app/linkly tools
```

(No checkpoint branches in your fork? Use `upstream/` after
`git remote add upstream https://github.com/sharjeelz/devops-course.git && git fetch upstream`.)

The examples use the region `eu-central-1` (Frankfurt). Pick the region closest to you and use it
everywhere: `export AWS_REGION=<your region>`.

## Lessons

1. [Your account and IAM](01-account-and-iam.md): a safe account, people, permissions, a budget
2. [Regions and VPCs](02-regions-and-vpc.md): your own network in the cloud
3. [EC2](03-ec2.md): a virtual machine you can SSH into
4. [Linkly on EC2](04-linkly-on-ec2.md): the whole app on one server, by hand
5. [S3](05-s3.md): storage, and backups without keys on the server
6. [ECR](06-ecr.md): AWS's own container registry
7. [Clean-up and costs](07-cleanup-and-costs.md): leave nothing running
8. [Landscape: other clouds](08-landscape.md): the same ideas on Azure and Google Cloud

By the end, `checkpoint/07-terraform` holds Linkly with its AWS files: where Module 7 starts.
