# Module 7 (Terraform) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild Module 6's hand-made AWS setup as Terraform. It covers the network, a server running Linkly from GHCR images at boot, and an S3 backup bucket with an instance role, plus remote state in S3 and reusable modules. `terraform apply` produces a working Linkly URL, and `terraform destroy` removes all of it. Seven lessons teach it.

**Verification without AWS (the user's standing choice from Module 6).** Nothing here calls AWS. The checks are:
- `terraform fmt -check` and `terraform validate` on every root;
- `terraform test` with a **mock AWS provider**. It runs real plan and apply logic without credentials; a spike proved this, and that it catches SSH opened to 0.0.0.0/0;
- the rendered EC2 start-up script, checked with `bash -n` and ShellCheck.

What can't be verified, such as real resource creation and boot timing, is stated in the lessons and the ledger.

**Tech Stack:** Terraform 1.16.6, AWS provider `~> 6.68`, S3 backend with `use_lockfile` (native S3 locking), cloud-init `user_data`, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-10-14-course-design.md`, module map row 7: "Module 6 as code: VPC, EKS, RDS, remote state, modules; landscape: Pulumi, OpenTofu, CloudFormation".
**Ruling (planned):** EKS and RDS move to Module 8, where they are used ("Production on EKS"). Module 7 builds the network module with two public subnets in two AZs, so Module 8 can add EKS to it. Cost if wrong: the module map's row 7/8 split differs from the spec, and the README says so.

## Global Constraints

- **Code lives in `app/linkly/terraform/`:**
  - `bootstrap/`: the state bucket, kept in local state.
  - `modules/network`, `modules/server`, `modules/backups`.
  - `envs/dev/`: the root that uses the modules, with the S3 backend.
  - `envs/dev/tests/*.tftest.hcl`.
- **Every resource is tagged** `Project=linkly-course`, `ManagedBy=terraform` through the provider's `default_tags`, so Module 6's `cleanup.sh` also finds them.
- **Same safety rules as Module 6:**
  - SSH and 8080 open only to `allowed_cidr` (a `/32`, validated);
  - IMDSv2 required;
  - no access keys; the instance role can only use its own bucket;
  - the bucket is private, versioned and encrypted;
  - `t3.micro` by default.
- **SSH key:** the learner's *public* key is passed in as a variable, so no private key ever appears in Terraform state.
- **No secrets in Git or state beyond Module 6's local Postgres default.** It's stated plainly, with Module 8 for real secrets.
- **Lesson format** as before, each lesson with a **Cost** line. Each header names "Start from: `checkpoint/07-terraform`", and the README brings files in from `checkpoint/08-eks`.
- Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **`allowed_cidr` set to `0.0.0.0/0` or not a `/32`.** Variable validation rejects it. Pinned in Task 3 by a `terraform test` `expect_failures`.
2. **The instance is replaced (e.g. a changed tag).** Linkly comes back by itself from `user_data`, with no manual step. Pinned in Task 2 by asserting the rendered user_data contains the install, the compose files and the `up` command, plus ShellCheck on the render.
3. **The state bucket.** It must be versioned, private and protected from accidental `destroy` (`prevent_destroy`). Pinned in Task 4 (bootstrap tests).
4. **Two people running `apply` at once.** The S3 backend locks with `use_lockfile = true`. Pinned in Task 4 (config asserted) and explained in a lesson.
5. **`terraform destroy` with a non-empty, versioned backup bucket** would fail. Use `force_destroy` on the course bucket, and say why it's acceptable here and dangerous in production. Pinned in Task 3 (test asserts it).

---

### Task 1: Network module

`modules/network`:
- **Inputs:** `name`, `cidr` (default `10.0.0.0/16`), `az_count` (default 2).
- **Creates:** a VPC with DNS hostnames, `az_count` public subnets (`cidrsubnet(cidr, 8, i+1)`) in the first AZs from `data.aws_availability_zones`, an IGW, and a public route table with `0.0.0.0/0` to the IGW and its associations. `map_public_ip_on_launch = true`.
- **Outputs:** `vpc_id`, `public_subnet_ids`.

### Task 2: Server and backups modules

`modules/backups`:
- **Inputs:** `name_prefix`, `force_destroy`.
- **Creates:** a bucket with a random suffix, with public access block, versioning, SSE-S3, and a lifecycle rule expiring noncurrent versions after 30 days and objects under `linkly-` after 90 days.
- **Outputs:** `bucket_name`, `bucket_arn`.

`modules/server`:
- **Inputs:** `name`, `vpc_id`, `subnet_id`, `allowed_cidr`, `ssh_public_key`, `instance_type`, `linkly_images`, `linkly_tag`, `backup_bucket_arn`.
- **Creates:**
  - a key pair from the public key;
  - a security group allowing 22 and 8080 from `allowed_cidr`, with all egress;
  - an IAM role (EC2 trust), an inline policy limited to the backup bucket, and an instance profile;
  - an `aws_instance` from the AL2023 SSM parameter, with IMDSv2 required, an encrypted root volume, `user_data_replace_on_change = true`, and `user_data` from `templatefile("user-data.sh.tftpl", …)`.
- **The user-data template** embeds `install-docker.sh`, `compose.yaml` and `compose.ghcr.yaml` with `file()`. It writes them to `/opt/linkly`, then runs the installer and `docker compose up -d` with `LINKLY_IMAGES`, `LINKLY_TAG` and `LINKLY_BASE_URL` (the instance's public address, fetched from IMDSv2 at boot).
- **Outputs:** `public_ip`, `url`, `instance_id`, `ssh_command`.

### Task 3: The dev environment and its tests

`envs/dev`:
- `providers.tf`: required version and provider, plus `default_tags`.
- `backend.tf`: S3, with `use_lockfile = true`. The bucket name is given at init with `-backend-config`.
- `variables.tf`: region, `allowed_cidr` validated as a `/32` and not `0.0.0.0`, `ssh_public_key`, images and tag (validated), `instance_type` (default `t3.micro`).
- `main.tf`: the three modules.
- `outputs.tf`.
- `terraform.tfvars.example`.

`envs/dev/tests/dev.tftest.hcl` uses a mock provider (`mock_data` for AZs and the SSM parameter) and runs `init -backend=false`. It asserts:
- SSH and 8080 are only from `allowed_cidr`;
- `0.0.0.0/0` is rejected (`expect_failures`);
- IMDSv2 is required;
- the root volume is encrypted;
- the instance type is `t3.micro`;
- the bucket is versioned, public access is blocked on all four settings, and `force_destroy` is set;
- the role policy names only the backup bucket;
- the user_data contains the installer, both compose files, the images and tag, and `compose up`;
- the outputs have a URL on port 8080;
- the provider's default tags are set.

The rendered user_data, written out by a test output, passes `bash -n` and ShellCheck.

### Task 4: Bootstrap (state bucket)

`bootstrap/` (local state) creates the state bucket: versioned, private, encrypted, `prevent_destroy`, with `force_destroy = false`. Its outputs give the name to pass to `-backend-config`. Tests run with the mock provider. `prevent_destroy` is asserted by reading the file, because `terraform test` can't observe lifecycle settings.

### Task 5: CI

Add a `terraform` job to ci.yml. It runs on every push and PR, with no credentials needed:
- `hashicorp/setup-terraform` with Terraform 1.16.6;
- `fmt -check -recursive`;
- for each root: `init -backend=false`, `validate`, `test`.

actionlint must report 0 findings.

### Task 6: Lessons

`modules/07-terraform/README.md` and seven lessons, each with a Cost line:
- `01-why-infrastructure-as-code`
- `02-first-configuration`
- `03-state`
- `04-modules`
- `05-linkly-as-code`
- `06-testing-and-ci`
- `07-landscape`

The lesson commands are terraform commands that can be checked offline (fmt/validate/test/plan with a mock, where possible). Any `aws` commands go through `tools/check-aws-commands.py`. The format check also requires the Cost line.

### Task 7: Checkpoint for Module 8

`checkpoint/08-eks` at HEAD, plus the README sentence.
