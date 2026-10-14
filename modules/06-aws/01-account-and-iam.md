# Your account and IAM

> **You need:** an AWS account (a new one is fine), the AWS CLI · **Time:** ~75 min · **Cost:** free · **Start from:** `checkpoint/06-aws`

## Why this matters

Most cloud disasters aren't clever attacks. They're a leaked access key on GitHub, a root user
without MFA, or a surprise bill. Ten minutes of setup prevents all three, and every later module
assumes you have a safe way to sign in and a budget alert watching your spending.

## Concept

- **The root user** is the email you signed up with. It can do *anything*, including close the
  account. Give it **MFA**, then stop using it day to day.
- **IAM Identity Center** is where people should come from: you create a user there, give them
  a **permission set** (e.g. `AdministratorAccess` while learning), and sign in through a portal.
  The CLI gets **short-lived credentials** that expire by themselves (`aws configure sso`, `aws sso login`).
- **IAM users with access keys** are long-lived passwords for programs. They're the thing that
  leaks. Avoid them for people; machines use **roles** instead (lesson 5).
- **Policies** say who may do what to which resource. *Identity-based* policies attach to a
  user or role; *resource-based* policies attach to a resource (an S3 bucket policy). Aim for
  **least privilege**: only what's needed.
- **Roles** are identities without passwords that something *assumes* for a while (an EC2
  instance, a CI job, another account).

## Example

1. **Root MFA:** sign in as root, then go to *Security credentials* and *Assign MFA device* (an
   authenticator app is fine).
2. **Identity Center:** in the console, enable *IAM Identity Center* in your chosen region, create
   a user for yourself, create a permission set `AdministratorAccess`, and assign it to your user
   for this account. Accept the email invitation and set a password and MFA.
3. **CLI sign-in with SSO:**

```bash
aws configure sso                          # session name: linkly; start URL: from the Identity Center dashboard;
                                           # region: yours; pick the account and role; profile name: linkly
aws sso login --profile linkly
export AWS_PROFILE=linkly AWS_REGION=eu-central-1
aws sts get-caller-identity                # your account and the role you're using
```

4. **A budget alert, first thing.** Put your email in `app/linkly/aws/notifications.json`
   (replace `you@example.com`), then:

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws budgets create-budget --account-id "$ACCOUNT_ID" \
  --budget file://app/linkly/aws/budget.json \
  --notifications-with-subscribers file://app/linkly/aws/notifications.json
aws budgets describe-budgets --account-id "$ACCOUNT_ID" --query 'Budgets[].[BudgetName,BudgetLimit.Amount]'
```

You'll get an email when actual spend passes 50% of $5, and when AWS *forecasts* you'll pass $5.

## Lab

- [ ] Turn on MFA for the root user
- [ ] Create your own Identity Center user with admin access
- [ ] Sign in from the CLI with aws configure sso and check who you are
- [ ] Create the $5 budget with an email alert
- [ ] Explain why you didn't create any access keys

## Check yourself

1. Why not just use the root user, with MFA?

<details><summary>Answer</summary>

It can't be limited in any way, some of its actions can't be undone (closing the account,
changing billing), and every mistake made with it is made with unlimited power. Keep it for the
rare tasks only it can do.

</details>

2. What's better about `aws sso login` than an access key in `~/.aws/credentials`?

<details><summary>Answer</summary>

The credentials expire on their own (hours, not forever), aren't stored long-term on disk, and
come from a sign-in with MFA. A leaked access key works until someone notices and deletes it.

</details>

3. Identity-based or resource-based policy: which is an S3 bucket policy?

<details><summary>Answer</summary>

Resource-based: it's attached to the bucket and says who may access it. Identity-based policies
are attached to users, groups or roles.

</details>
