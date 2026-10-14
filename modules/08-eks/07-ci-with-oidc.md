# CI with OIDC

> **You need:** Lessons 2–3, Module 7's state bucket · **Time:** ~45 min · **Cost:** free (IAM and OIDC providers cost nothing) · **Start from:** `checkpoint/08-eks`

## Why this matters

Module 7 promised that pull requests could show a `terraform plan` against the real account.
That needs AWS credentials in CI, and an access key stored in GitHub is a long-lived secret
waiting to leak. With **OIDC**, GitHub proves *which workflow is running* and AWS hands out
credentials for an hour. There's nothing to store, rotate or leak.

## Concept

- **OIDC provider:** you tell AWS to trust tokens signed by
  `https://token.actions.githubusercontent.com` (GitHub's issuer) for the audience `sts.amazonaws.com`.
- **The token's claims** say who's asking, e.g. `sub = repo:<you>/devops-course:ref:refs/heads/main`
  or `repo:<you>/devops-course:pull_request`.
- **The role's trust policy** checks them: this repository, main or pull requests, nothing else.
  A fork's workflow, or another repo, gets nothing. (Pull requests from forks get no OIDC token at all.)
- **Least privilege:** the plan role has `ReadOnlyAccess`, plus write access only to the state
  bucket (plan takes a lock file). It can look at everything and change nothing.
- **In the workflow:** `permissions: id-token: write` lets the job request a token, and
  `aws-actions/configure-aws-credentials` swaps it for the role's credentials. The CI job
  `terraform-plan` does this, and is skipped until you set the repository variables.

## Example

```bash
cd app/linkly/terraform/envs/github-ci
terraform init -backend-config="bucket=<state bucket>" -backend-config="region=$AWS_REGION"
terraform apply -var repository=<you>/devops-course -var state_bucket=<state bucket>
terraform output -raw role_arn
```

In your fork on GitHub: *Settings → Secrets and variables → Actions → Variables*, add:

| Variable | Value |
|---|---|
| `AWS_PLAN_ROLE_ARN` | the role_arn output |
| `AWS_REGION` | your region |
| `TF_STATE_BUCKET` | the state bucket's name |
| `TF_ALLOWED_CIDR` | your /32 |

These are variables, not secrets: none of them is sensitive. Push to main, and the
`terraform-plan` job shows the plan for `envs/eks`, with no key stored anywhere.

## Lab

- [ ] Create the OIDC provider and plan role
- [ ] Set the four repository variables
- [ ] Watch the terraform-plan job run on a push
- [ ] Explain which workflows the role refuses
- [ ] Explain why the role can't apply

## Check yourself

1. Someone copies your workflow file into their own repository. Can it use your role?

<details><summary>Answer</summary>

No. Their token's `sub` names their repository, and your role's trust policy only accepts yours.

</details>

2. Why not give the CI role `AdministratorAccess` so it can apply too?

<details><summary>Answer</summary>

Then any change merged to main, or any compromised step in the pipeline, could change or
destroy the account. Applying is a separate, deliberate decision; many teams require an approval
step and a separate, narrower role for it.

</details>

## Clean up

The provider and role cost nothing; remove them with `terraform destroy` in `envs/github-ci` when
you no longer want CI plans. Delete the repository variables too, or the job will fail.
