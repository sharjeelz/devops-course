# Ansible

> **You need:** Modules 1 and 7 · **Time:** ~8 hours · **Start from:** `checkpoint/09-ansible`

Not everything runs on Kubernetes. Module 7's server, a bastion host, a build machine, a database
server: they're machines with an operating system that someone has to install packages on, lock
down and keep that way. So far that was a script that runs once (`user_data`). In this module it
becomes **Ansible**: a description of how each machine should be, applied over SSH, as often as
you like, changing only what's different.

> **Costs: free, except lesson 6.** Lessons 1–5 run in a lab on your laptop: an Ansible control
> node and two Amazon Linux 2023 "servers" in containers. Lesson 6 configures a real EC2 server
> built by Module 7's Terraform (about $0.02/hour) and ends with `terraform destroy`.

## Install

- **Docker Desktop** (or Docker Engine) from Module 1. The lab's control container has Ansible in
  it, so you don't need Ansible on your machine. (Ansible doesn't run on Windows itself; there you'd
  use WSL. On Linux or macOS you can also `pipx install ansible-core==2.21.5`.)
- For lesson 6: **Terraform** and the **AWS CLI** from Modules 6–7.

## Before you start

```bash
git switch main && git pull
git checkout origin/checkpoint/10-python -- app/linkly tools .github
```

(No checkpoint branches in your fork? Use `upstream/` after
`git remote add upstream https://github.com/sharjeelz/devops-course.git && git fetch upstream`.)

## Lessons

1. [Inventory and ad-hoc commands](01-inventory-and-ad-hoc.md): the lab, SSH, a bastion
2. [Playbooks and idempotence](02-playbooks.md): describe the state, run it twice
3. [Roles and templates](03-roles.md): common, bastion, docker, linkly
4. [Secrets with Ansible Vault](04-vault.md): Linkly's database password, encrypted in Git
5. [Testing and CI](05-testing-and-ci.md): ansible-lint, check mode, the second run, the lab in CI
6. [Real servers](06-real-servers.md): Terraform builds it, Ansible configures it
7. [Landscape: configuring machines](07-landscape.md): cloud-init, golden images, Chef, Puppet, Salt

By the end, `checkpoint/10-python` holds Linkly with everything from this module: where Module 10 starts.
