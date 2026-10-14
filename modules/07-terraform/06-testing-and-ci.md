# Testing and CI

> **You need:** Lessons 2–5 · **Time:** ~60 min · **Cost:** free (no AWS needed) · **Start from:** `checkpoint/07-terraform`

## Why this matters

Infrastructure mistakes are expensive: an open SSH port, a public bucket, a role that can read
everything. You want to catch them in a pull request, before anything exists, and ideally without
an AWS account at all, so CI can check every change for free.

## Concept

- **`terraform fmt -check`** and **`terraform validate`:** formatting and syntax/type errors, offline.
- **`terraform test`:** `.tftest.hcl` files with `run` blocks that `plan` or `apply` the
  configuration and `assert` things about the result. With a **mock provider**
  (`mock_provider "aws" {}`), it runs against a fake AWS: computed values like IDs are made up,
  so no account and no credentials are needed.
- **What Linkly's tests check** (`*/tests/*.tftest.hcl`):
  - SSH and 8080 only from one `/32`, IMDSv2 required, an encrypted disk, and a role that can only
    touch its own bucket;
  - a private, versioned bucket;
  - a start-up script that really starts Linkly;
  - and `expect_failures` runs proving bad inputs are refused (`0.0.0.0/0`, a private key, `latest`).
- **Tests that can fail.** Every test was checked by breaking the code on purpose (open SSH,
  optional IMDSv2, an unencrypted disk…) and watching it fail. One test passed anyway: it looked
  for the `docker compose … up` command, which also appears in a comment inside an embedded file.
  It now matches the command only at the start of a line. A test you've never seen fail proves nothing.
- **`tools/check-terraform.sh`** runs all of it, plus ShellCheck on the start-up script as
  Terraform renders it. CI runs it on every push (the `terraform` job).
- **Plans in pull requests:** real teams also run `terraform plan` in CI against the real
  account and post it on the PR. That needs AWS credentials in CI, done safely with **OIDC**: GitHub
  proves the workflow's identity to AWS, which hands out a short-lived role. No stored keys. It's
  covered in Module 8.

## Example

```bash
tools/check-terraform.sh                         # fmt, validate and every test, about a minute
cd app/linkly/terraform/modules/server && terraform test   # one module's tests
```

Break something and watch a test catch it: in `modules/server/main.tf`, change the SSH rule's
`cidr_ipv4 = var.allowed_cidr` to `cidr_ipv4 = "0.0.0.0/0"`, run `terraform test` in that folder
(`run "only_one_address_reaches_ssh_and_linkly"... fail`), then undo it.

## Lab

- [ ] Run the whole Terraform check
- [ ] Break a security rule and watch a test fail
- [ ] Write a new assertion (for example, that the instance has a Name tag)
- [ ] Find the terraform job in your CI runs

## Check yourself

1. What does a mock provider make possible, and what can't it tell you?

<details><summary>Answer</summary>

It lets plan/apply logic, references, validations and your assertions run with no AWS account.
It can't tell you that AWS will accept the real request (a quota, a region without that
instance type, a name already taken). That only shows up on a real apply.

</details>

2. Why does CI plan against real AWS use OIDC instead of access keys?

<details><summary>Answer</summary>

No long-lived secret is stored in GitHub. Each run gets short-lived credentials for a role that
trusts only that repository (and branch), so there's nothing worth stealing.

</details>
