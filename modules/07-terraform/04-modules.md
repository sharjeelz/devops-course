# Modules

> **You need:** Lesson 3 · **Time:** ~60 min · **Cost:** free (reading and planning only) · **Start from:** `checkpoint/07-terraform`

## Why this matters

One big file for everything turns into copy-paste the moment you want a second environment or a
second app. **Modules** package a piece of infrastructure with clear inputs and outputs, so you
can reuse it, test it on its own, and read an environment as a short list of building blocks.

## Concept

- **A module is a folder of `.tf` files.** Every configuration is a module; the one you run
  commands in is the *root* module, and it calls *child* modules with `module "name" { source = … }`.
- **Inputs** are its variables, **outputs** are what it hands back. Everything else inside is
  private: the root can't reach into a module's resources.
- **Linkly's three modules** (`app/linkly/terraform/modules/`):

| Module | Builds | Takes | Gives back |
|---|---|---|---|
| `network` | VPC, two public subnets in two AZs, gateway, routes | `name`, `cidr`, `az_count` | `vpc_id`, `public_subnet_ids` |
| `backups` | a private, versioned, encrypted bucket with expiry rules | `name_prefix`, `force_destroy` | `bucket_name`, `bucket_arn` |
| `server` | key pair, security group, role + profile, EC2 instance | network IDs, `allowed_cidr`, key, images, tag, bucket ARN | `url`, `public_ip`, `ssh_command` |

- **The environment wires them together** (`envs/dev/main.tf`): the network's subnet goes into the
  server; the bucket's ARN goes into the server's role policy. Data flows through outputs → inputs.
- **Validation:** variables can check their values. `envs/dev` refuses `0.0.0.0/0`, a private key
  pasted by mistake, and the `latest` tag before anything is planned.
- **Registry modules:** the Terraform Registry has well-maintained community modules (e.g.
  `terraform-aws-modules/vpc/aws`, which Module 8's EKS uses). Pin their versions like providers.

## Example

```bash
cd app/linkly/terraform/envs/dev
cat main.tf                                   # three module blocks
terraform plan                                # resources named module.network.aws_vpc.this, …
terraform plan -var allowed_cidr=0.0.0.0/0    # refused by the variable's validation
```

(Planning uses your AWS credentials to read things like the AZ list; nothing is created.)

## Lab

- [ ] Read each module's inputs and outputs
- [ ] Trace how the subnet ID gets from the network module to the server
- [ ] Trigger a variable validation error on purpose
- [ ] Explain why the root can't change a module's internal resources directly

## Check yourself

1. Why does the server module take `backup_bucket_arn` as an input instead of creating the bucket itself?

<details><summary>Answer</summary>

Separation: the bucket's lifetime and settings are a different concern, and other things may
use it. Passing the ARN keeps the server module focused, and lets the role policy name exactly
that one bucket.

</details>

2. What does pinning a registry module's version protect you from?

<details><summary>Answer</summary>

A new release changing behaviour or resource names under you, which can mean surprise
replacements on your next plan. You upgrade deliberately, reading the plan.

</details>
