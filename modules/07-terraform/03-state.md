# State

> **You need:** Lesson 2 · **Time:** ~60 min · **Cost:** cents (a small S3 bucket for state) · **Start from:** `checkpoint/07-terraform`

## Why this matters

After lesson 2's apply, a file called `terraform.tfstate` appeared. It's how Terraform knows that
`aws_vpc.lab` *is* `vpc-0abc…`. Lose it and Terraform forgets everything it built; keep it only on
your laptop and nobody else (and no CI) can safely change the infrastructure. Real teams keep
state remotely, versioned and locked.

## Concept

- **State** maps each resource in the code to a real object, and stores its attributes.
- **It can contain secrets.** Some resources record passwords or keys in state. Treat it like a
  secret: private bucket, encryption, limited access, never in Git (`app/linkly/terraform/.gitignore`
  excludes it).
- **Remote state (S3 backend):** the state file lives in a bucket. The `envs/dev/backend.tf` sets
  `use_lockfile = true`, so while someone runs `plan` or `apply`, Terraform holds a lock object in
  the bucket, and a second run waits or fails instead of corrupting the state. (Older setups needed
  a DynamoDB table for this; since Terraform 1.10, S3 can do it alone.)
- **Bootstrap:** the state bucket can't keep its own state in itself before it exists, so
  `app/linkly/terraform/bootstrap/` creates it with *local* state, once. It's versioned (every
  state change kept), private, encrypted, and has `prevent_destroy`, so `terraform destroy` refuses to delete it.
- **Inspect, don't edit:** `terraform state list` and `terraform state show <address>`.
  Hand-editing state is how people lose infrastructure.

## Example

Create the state bucket:

```bash
cd app/linkly/terraform/bootstrap
terraform init
terraform apply -var region="$AWS_REGION"
terraform output -raw state_bucket          # linkly-course-tfstate-…: copy it
```

Point the dev environment at it:

```bash
cd ../envs/dev
terraform init -backend-config="bucket=<the state bucket>" -backend-config="region=$AWS_REGION"
```

After lesson 5's apply, the state is in S3, not on your disk:

```bash
aws s3 ls "s3://<the state bucket>/linkly/dev/"
terraform state list                         # every resource Terraform manages here
terraform state show module.server.aws_instance.this
```

## Lab

- [ ] Create the state bucket with the bootstrap configuration
- [ ] Initialise the dev environment against it
- [ ] Find the state file in S3 after an apply
- [ ] Explain what the lock file prevents
- [ ] Explain why the state bucket has prevent_destroy

## Check yourself

1. Two people run `terraform apply` at the same moment. What happens with `use_lockfile`?

<details><summary>Answer</summary>

The first takes the lock; the second fails with a lock error (or waits, with `-lock-timeout`)
instead of both writing the state and corrupting it.

</details>

2. Why is versioning on the state bucket worth having?

<details><summary>Answer</summary>

Every change to the state is kept. If an apply goes wrong or the state gets damaged, you can see
exactly what changed and restore an earlier version.

</details>

## Clean up

The state bucket stays for lesson 5. At the very end of the course, Module 6's `cleanup.sh`
removes it (it deletes buckets named `linkly-course-*`, every version included).
