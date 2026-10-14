# Linkly as code

> **You need:** Lessons 3–4 (state bucket created, `envs/dev` initialised) · **Time:** ~60 min · **Cost:** about $0.02 per hour while it runs (t3.micro + public IPv4), cents for S3 · **Start from:** `checkpoint/07-terraform`

## Why this matters

This is the payoff. Everything Module 6 did by hand (network, server, Docker, Linkly, backups
bucket, role) comes from one `terraform apply`. And when you want a new version or a fresh
server, the machine sets itself up, because the steps are written down in the code.

## Concept

- **`user_data`:** a script the instance runs once, as root, on first boot (cloud-init).
  Terraform renders it from `modules/server/user-data.sh.tftpl`, embedding three files:
  `install-docker.sh`, `compose.yaml` and `compose.ghcr.yaml`. The script installs Docker and
  Compose, asks the metadata service (IMDSv2) for the instance's public address, and starts Linkly
  from your images with `LINKLY_BASE_URL` set to it.
- **`user_data_replace_on_change = true`:** change the tag and Terraform *replaces* the instance,
  so the new one boots and sets itself up from scratch. A server you can replace without thinking
  is a server you can trust.
- **What doesn't replace it:** a newer Amazon Linux release. The AMI comes from a parameter that
  always points at the newest one, so the instance has `ignore_changes = [ami]`; otherwise a
  routine `apply` weeks later would replace the server and lose its database. The start-up script
  also writes `/opt/linkly/.env`, so `docker compose` commands work when you SSH in later
  (`cd /opt/linkly && sudo docker compose -f compose.yaml -f compose.ghcr.yaml ps`).
- **tfvars:** your own values (`allowed_cidr`, your public key, images, tag) go in
  `terraform.tfvars`, which Git ignores. Copy `terraform.tfvars.example`.
- **Your SSH key:** Terraform gets your *public* key; the private key never leaves your machine,
  and never lands in state.

## Example

```bash
cd app/linkly/terraform/envs/dev
cp terraform.tfvars.example terraform.tfvars
# edit it: allowed_cidr = "<your IP>/32", ssh_public_key = "<contents of ~/.ssh/id_ed25519.pub>",
#          linkly_images = "ghcr.io/<you>", linkly_tag = "sha-<a build>"
terraform plan
terraform apply
terraform output url
```

The instance needs a few minutes after `apply` finishes to install Docker and pull the images.
Then open the URL. To watch it happen:

```bash
ssh ec2-user@<public ip> 'sudo tail -f /var/log/linkly-setup.log'    # "Linkly is up at http://…:8080"
```

A new build is one changed variable:

```bash
terraform apply -var linkly_tag=sha-<a newer build>       # plan: the instance "must be replaced"
```

## Lab

- [ ] Fill in your terraform.tfvars and apply the dev environment
- [ ] Open Linkly at the URL Terraform prints
- [ ] Read the set-up log on the instance
- [ ] Deploy a different build by changing linkly_tag
- [ ] Destroy the environment and confirm the state bucket survives

## Check yourself

1. Why does changing `linkly_tag` replace the instance instead of updating it?

<details><summary>Answer</summary>

`user_data` only runs on first boot. With `user_data_replace_on_change`, a new start-up script
means a new instance that runs it, so every server is built the same way from scratch.

</details>

2. What's lost when the instance is replaced, and what would fix that?

<details><summary>Answer</summary>

Everything on its disk, including Linkly's database. Back it up to the bucket (Module 6, lesson
5), or move the database to a managed service (RDS, Module 8) whose lifetime isn't tied to the server.

</details>

## Clean up

`terraform destroy` removes the server, network and backup bucket (`force_destroy` lets it delete
the backups too, which is fine for a course and something to think hard about in production). The
state bucket stays until the end of the course.
