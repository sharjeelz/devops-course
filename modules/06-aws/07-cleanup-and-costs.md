# Clean-up and costs

> **You need:** whatever you created in lessons 2–6 · **Time:** ~30 min · **Cost:** this lesson *stops* the costs · **Start from:** `checkpoint/06-aws`

## Why this matters

The classic first cloud bill is a forgotten instance, or worse, a forgotten NAT gateway or load
balancer. Cleaning up is a skill: knowing what costs money while idle, finding everything you
made, and deleting it in an order AWS accepts.

## Concept

- **What costs money while doing nothing:** running instances, public IPv4 addresses, EBS volumes
  and snapshots, NAT gateways, load balancers, and to a lesser degree storage (S3, ECR). VPCs,
  subnets, route tables, security groups and IAM cost nothing.
- **Order matters.** AWS refuses to delete things still in use: instances must be gone before
  their security groups, the internet gateway must be detached before the VPC can go, and a bucket
  must be empty (every version) before it can be deleted.
- **Tags make clean-up possible.** Everything in this module carries `Project=linkly-course`, so
  it can be found again, and with cost allocation tags turned on, costed separately in the bill.
- **`app/linkly/aws/cleanup.sh`** deletes everything this module creates in one region, in the right
  order. It's safe to run twice, and `DRY_RUN=1` only lists. It's tested against a fake `aws` that
  records the order of every call (`app/linkly/aws/test-cleanup.sh`).

## Example

```bash
aws resourcegroupstaggingapi get-resources --tag-filters Key=Project,Values=linkly-course \
  --query 'ResourceTagMappingList[].ResourceARN'          # everything tagged for the course

DRY_RUN=1 app/linkly/aws/cleanup.sh                        # what would go
app/linkly/aws/cleanup.sh                                  # delete it all (waits for the instance)

aws resourcegroupstaggingapi get-resources --tag-filters Key=Project,Values=linkly-course \
  --query 'ResourceTagMappingList[].ResourceARN'          # []
```

Then look at your bill: the console's **Billing and Cost Management** home, and **Cost Explorer**
grouped by service. (The Cost Explorer API charges per request; the console doesn't.) Your budget
from lesson 1 keeps watching.

The tag search can lag a few minutes behind deletions, and a terminated instance stays listed as
"terminated" for about an hour at no cost.

## Lab

- [ ] List everything tagged for the course
- [ ] Run the clean-up script as a dry run, then for real
- [ ] Confirm nothing tagged is left
- [ ] Find this module's cost in the billing console

## Check yourself

1. Which of these cost money while idle: a VPC, a stopped instance's disk, a security group, a public IPv4 address?

<details><summary>Answer</summary>

The stopped instance's EBS disk and the public IPv4 address (if it's still allocated). The VPC
and security group are free.

</details>

2. Why can't the script just delete the VPC first?

<details><summary>Answer</summary>

AWS refuses to delete a VPC that still has instances, subnets, an attached internet gateway or
security groups in it. Dependencies have to go first, in order.

</details>
