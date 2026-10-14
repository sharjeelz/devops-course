# Why infrastructure as code

> **You need:** Module 6 done · **Time:** ~40 min · **Cost:** free · **Start from:** `checkpoint/07-terraform`

## Why this matters

Look at what Module 6 took: a VPC, a subnet, a gateway, a route table, a security group, a key
pair, an instance, a role, a profile, a bucket. Each one was created by a command whose output
(an ID) you pasted into the next. Now imagine a second environment, a teammate repeating it, or
rebuilding it after a mistake at 2 a.m. Infrastructure as code (IaC) makes your infrastructure as
reviewable, repeatable and versioned as your application.

## Concept

- **Imperative** (Module 6): a list of *steps*: create this, then that, then attach them. Run it
  twice and you get two of everything, or errors.
- **Declarative** (Terraform): a description of the *result*: "there is a VPC with this range
  and a subnet in it". Terraform works out the steps.
- **The core loop:**
  - `terraform plan`: compare the code with what exists and show the difference (create /
    change / destroy). Nothing changes yet.
  - `terraform apply`: make the difference real.
  - `terraform destroy`: remove everything the code describes.
- **Idempotent:** applying the same code twice changes nothing the second time.
- **State:** Terraform's record of which real resource belongs to which piece of code (lesson 3).
- **Drift:** when someone changes infrastructure by hand, the next `plan` shows it, and `apply`
  puts it back, the same idea as Argo CD's self-healing in Module 5.

## Example

Compare Module 6, lesson 2 (eleven commands, four IDs to carry around) with its Terraform
version in `app/linkly/terraform/modules/network/main.tf`:

```bash
cat app/linkly/terraform/modules/network/main.tf
```

The `aws_route_table` refers to `aws_internet_gateway.this.id` instead of a pasted `igw-…`.
Terraform reads those references to work out the order: gateway first, then the route.

## Lab

- [ ] Count the AWS commands Module 6 needed to build Linkly's setup
- [ ] Find the network module's version of each one
- [ ] Explain the difference between plan and apply
- [ ] Explain what drift is and how Terraform shows it

## Check yourself

1. What happens if you run `terraform apply` twice in a row with no changes?

<details><summary>Answer</summary>

The second run's plan shows "No changes": everything already matches the code, so nothing is
created or modified. That's idempotence.

</details>

2. How does Terraform know to create the internet gateway before the route that uses it?

<details><summary>Answer</summary>

From references: the route's `gateway_id = aws_internet_gateway.this.id` makes it depend on the
gateway. Terraform builds a dependency graph from those references and works in order, in
parallel where it can.

</details>
