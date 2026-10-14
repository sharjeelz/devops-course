# Your first configuration

> **You need:** Terraform installed, signed in to AWS (module README) · **Time:** ~60 min · **Cost:** free (a VPC costs nothing) · **Start from:** `checkpoint/07-terraform`

## Why this matters

Before using Linkly's modules, write a tiny configuration yourself: one provider, one resource,
one variable, one output. Then watch the whole lifecycle (init, plan, apply, change, destroy) on
something that costs nothing.

## Concept

- **HCL:** Terraform's language. Blocks (`resource "type" "name" { … }`), arguments
  (`cidr_block = "10.0.0.0/16"`), and references (`aws_vpc.lab.id`).
- **Provider:** a plugin that talks to an API (`hashicorp/aws`). Pin its version range so a new
  major release can't surprise you. `terraform init` downloads it and records the exact version
  in `.terraform.lock.hcl`; commit that file.
- **Resource:** something Terraform creates and manages. **Data source:** something it only
  *reads* (the latest AMI, the list of AZs).
- **Variables** are inputs; **outputs** are what a configuration reports back.
- **`default_tags`** in the provider tags every resource automatically.

## Example

In a scratch folder (not in the repo), create `main.tf`:

```hcl
terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.68" }
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = { Project = "linkly-course", ManagedBy = "terraform" }
  }
}

variable "region" {
  type    = string
  default = "eu-central-1"
}

resource "aws_vpc" "lab" {
  cidr_block = "10.42.0.0/16"
  tags       = { Name = "terraform-lab" }
}

output "vpc_id" {
  value = aws_vpc.lab.id
}
```

```bash
terraform init          # downloads the AWS provider
terraform fmt           # tidy formatting
terraform validate      # catches typos and type errors without calling AWS
terraform plan          # "1 to add"
terraform apply         # type yes; prints vpc_id
```

Now change `cidr_block` to `10.43.0.0/16` and run `terraform plan`. It says **"must be
replaced"**, because a VPC's range can't change in place. Some changes update a resource; others
destroy and recreate it, and the plan always tells you which. Finish with `terraform destroy`.

## Lab

- [ ] Write a configuration with one VPC, a variable and an output
- [ ] Run init, plan and apply, and find the VPC in the AWS console
- [ ] Change something that forces a replacement and read the plan
- [ ] Destroy it and confirm it's gone

## Check yourself

1. Why commit `.terraform.lock.hcl` but never `.terraform/`?

<details><summary>Answer</summary>

The lock file records the exact provider versions (and checksums), so everyone and CI use the
same ones. `.terraform/` is just the downloaded plugins, which `terraform init` recreates.

</details>

2. Resource or data source: which is the latest Amazon Linux AMI?

<details><summary>Answer</summary>

A data source: Terraform only reads it. It doesn't create or own the AMI.

</details>

## Clean up

`terraform destroy` in your scratch folder. A VPC costs nothing, but leave nothing behind.
