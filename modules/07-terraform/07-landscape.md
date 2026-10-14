# Landscape: IaC tools

> **You need:** Lessons 1–6 · **Time:** ~30 min · **Cost:** free · **Start from:** `checkpoint/07-terraform`

## Why this matters

Terraform is the most widely used infrastructure-as-code tool, but not the only one, and its
licence changed in 2023, which split the community. You'll meet OpenTofu, Pulumi, CloudFormation
and others. The ideas transfer; knowing the trade-offs helps you choose and fit in.

## Concept

- **OpenTofu:** in August 2023 HashiCorp moved Terraform from an open-source licence (MPL) to the
  Business Source License. The community forked the last open version as **OpenTofu**, now under
  the Linux Foundation and still MPL-licensed. It reads the same HCL, uses the same providers, and
  is mostly a drop-in replacement (`tofu init`, `tofu plan`). The two have since diverged a
  little in new features.
- **Pulumi:** infrastructure in a general-purpose language (TypeScript, Python, Go, C#), with
  real loops, functions and tests from your language. It's powerful, and it's easy to write
  infrastructure that's as hard to read as any program.
- **AWS CloudFormation / CDK:** AWS's own IaC. CloudFormation is YAML/JSON templates, with state
  managed by AWS. The CDK generates CloudFormation from code. Both are AWS-only.
- **Crossplane:** infrastructure as Kubernetes resources, reconciled continuously, GitOps-style
  (Module 5's ideas applied to cloud resources).
- **Terragrunt:** a wrapper that keeps many Terraform environments DRY (shared backends, inputs).
- **Configuration management** (Ansible, Module 9) is a different job: setting up *inside*
  machines rather than creating them. The tools often work together.

## Example

The same network in Pulumi (Python), for comparison only (not run):

```python
import pulumi_aws as aws

vpc = aws.ec2.Vpc("linkly", cidr_block="10.0.0.0/16", enable_dns_hostnames=True)
subnet = aws.ec2.Subnet("public-1", vpc_id=vpc.id, cidr_block="10.0.1.0/24", map_public_ip_on_launch=True)
igw = aws.ec2.InternetGateway("linkly", vpc_id=vpc.id)
```

And Linkly's own configuration under OpenTofu:

```bash
cd app/linkly/terraform/modules/network && tofu init && tofu test    # if you install OpenTofu
```

## Lab

- [ ] Explain why OpenTofu exists
- [ ] Compare HCL with a Pulumi program for the same VPC
- [ ] Name one situation where CloudFormation would be the natural choice

## Check yourself

1. Can you switch Linkly's configuration from Terraform to OpenTofu?

<details><summary>Answer</summary>

Very likely yes: it's standard HCL with the AWS provider, which OpenTofu supports. You'd test it
(`tofu test`) and check any feature that has diverged between the two since the fork.

</details>

2. What's the main trade-off of Pulumi compared with HCL?

<details><summary>Answer</summary>

A full programming language gives loops, abstractions and familiar tooling, but also every way
to make code complex. HCL is deliberately limited, which keeps configurations readable and plans predictable.

</details>
