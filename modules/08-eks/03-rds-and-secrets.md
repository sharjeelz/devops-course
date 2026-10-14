# RDS and secrets

> **You need:** Lesson 2 (the EKS environment applied) · **Time:** ~60 min · **Cost:** included in lesson 2's ~$0.25/hour · **Start from:** `checkpoint/08-eks`

## Why this matters

So far Linkly's database lived next to the app, with a password in a values file. In production
the database is the one thing you can't lose, so it goes to a managed service with backups and
patches, and its password is something no human types, sees or commits.

## Concept

- **RDS** runs Postgres for you: automated backups, minor-version patching, encryption, optional
  Multi-AZ standby (off here: it doubles the cost). It sits in the **private** subnets, and its
  security group lets in **only the cluster's security group**, not an address range.
- **`manage_master_user_password = true`:** RDS generates the password and stores it in **AWS
  Secrets Manager** as `{"username": ..., "password": ...}`, and **rotates** it (every 7 days by
  default). It's not in Terraform's code or state.
- **External Secrets Operator (ESO)** copies secrets from an external store into Kubernetes Secrets:
  - a `ClusterSecretStore` says *where* (`app/linkly/eks/cluster-secret-store.yaml`: Secrets
    Manager in your region);
  - an `ExternalSecret` (rendered by the chart) says *what*: read the RDS secret, build
    `DATABASE_URL`, write `linkly-db`, and check again every minute.
- **EKS Pod Identity:** how ESO gets AWS permissions **without keys**. Terraform creates a role
  that only `pods.eks.amazonaws.com` can assume, allows it to read *only the database's secret*,
  and associates it with the `external-secrets` service account. The Pod Identity agent hands
  that pod short-lived credentials. (The older way, IRSA, does the same with an OIDC provider.)
- **Rotation:** RDS changes the password; within a minute ESO updates `linkly-db`; **Reloader**
  sees the change and restarts the api and worker, which read the new URL. You rehearsed exactly
  this in lesson 1.

## Example

```bash
cd app/linkly/terraform/envs/eks
terraform output db_host db_secret_arn
aws rds describe-db-instances --db-instance-identifier linkly-course-eks \
  --query 'DBInstances[0].[DBInstanceStatus,PubliclyAccessible,StorageEncrypted,MasterUserSecret.SecretArn]'
aws secretsmanager describe-secret --secret-id "$(terraform output -raw db_secret_arn)" \
  --query '[Name,RotationEnabled,NextRotationDate]'
```

The add-ons and the store come in lesson 4, together with Linkly. You can look at the secret's
value in the console (Secrets Manager → the `rds!db-…` secret → *Retrieve secret value*), but notice
that nothing in this course ever needs you to.

## Lab

- [ ] Find the database's endpoint and secret ARN
- [ ] Show that the database isn't publicly accessible
- [ ] Find when Secrets Manager will next rotate the password
- [ ] Explain how External Secrets gets AWS permissions without keys

## Check yourself

1. Why does the database's security group reference the cluster's security group instead of the VPC's range?

<details><summary>Answer</summary>

Only things carrying that group, which means the cluster's nodes, can connect. Anything else in
the VPC, now or later, can't, even with an address inside the range.

</details>

2. ESO's role can read one secret. What would be the risk of `secretsmanager:*` on `*`?

<details><summary>Answer</summary>

Anyone who can create an ExternalSecret could pull any secret in the account into the cluster,
and the role could also change or delete secrets. Least privilege limits the damage of a mistake
or a compromised pod.

</details>
