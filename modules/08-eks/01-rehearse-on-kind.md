# Rehearse on kind

> **You need:** Docker, kind, kubectl, Helm · **Time:** ~60 min · **Cost:** free · **Start from:** `checkpoint/08-eks`

## Why this matters

An EKS cluster bills by the hour, and the most expensive way to learn is to debug on it. Almost
everything that runs *inside* the cluster can be rehearsed on kind first: the add-ons, the chart's
production values, secrets coming from a secret store, certificates, autoscaling, even a password
rotation. Then on EKS, you only meet what's genuinely AWS.

## Concept

- **Production Linkly differs from Module 4's in four ways** (all in `helm/linkly/values-eks.yaml`):
  - The database is **outside** the cluster (RDS). The chart drops its Postgres and expects a
    `linkly-db` Secret with a `DATABASE_URL`.
  - That Secret is made by **External Secrets** from a secret in AWS Secrets Manager, so the password
    never appears in Git, values files or Helm's history.
  - The Gateway serves **HTTPS** with a certificate from **cert-manager**, and HTTP redirects to it.
  - The api is **autoscaled** (an HPA) and protected during node drains (a PodDisruptionBudget).
- **Add-ons** are cluster-wide software Linkly relies on. `app/linkly/eks/addons.sh` installs the
  same pinned versions on kind and on EKS: Envoy Gateway, cert-manager, External Secrets,
  Reloader, metrics-server.
- **Stand-ins** replace only what AWS provides (`app/linkly/eks/rehearsal/`):

| On EKS | In the rehearsal |
|---|---|
| RDS | a Postgres in another namespace, with a password like `p@ss:w/rd#1%+x?` |
| Secrets Manager | External Secrets' `fake` provider, serving the same JSON shape RDS stores |
| Let's Encrypt | a self-signed issuer with the same name, `letsencrypt` |

- **Why that ugly password?** A generated password can contain `@ / : # % +`, which mean something
  in a URL. The chart escapes them (`urlquery`) when it builds `DATABASE_URL`. The rehearsal proves
  it, instead of finding out on the night RDS rotates the password.

## Example

```bash
app/linkly/eks/rehearse-on-kind.sh          # ~10 minutes; KEEP=1 keeps the cluster afterwards
```

It creates a kind cluster, installs the add-ons and stand-ins, installs Linkly with the EKS values,
and then checks, in order:
1. the database URL came from the secret store, correctly escaped;
2. Linkly answers over HTTPS through the Gateway, with a certificate, and HTTP redirects;
3. the autoscaler can read the api's CPU;
4. after the password is rotated (in Postgres and in the "secret store"), the new one reaches the
   Secret, Reloader restarts the pods, and Linkly still works.

With `KEEP=1`, look around:

```bash
kubectl -n linkly get externalsecret,secret linkly-db
kubectl -n linkly get certificate,gateway,httproute,hpa,pdb
kubectl -n linkly get secret linkly-db -o jsonpath='{.data.DATABASE_URL}' | base64 -d; echo
kind delete cluster --name linkly-rehearsal
```

## Lab

- [ ] Run the rehearsal until it passes
- [ ] Find where the escaped password appears in DATABASE_URL
- [ ] Explain what each stand-in replaces on AWS
- [ ] Explain why a rotated password needs Reloader

## Check yourself

1. Why does the chart build `DATABASE_URL` in the ExternalSecret instead of reading a ready-made URL?

<details><summary>Answer</summary>

RDS stores a username and password, not a URL. External Secrets' template combines them with the
host, escaping both, so one source of truth (Secrets Manager) feeds the app's format.

</details>

2. RDS rotates the password. What would happen without Reloader?

<details><summary>Answer</summary>

External Secrets updates the `linkly-db` Secret, but running pods read `DATABASE_URL` from the
environment when they start. They'd keep the old password and fail to connect until restarted.

</details>

## Clean up

The script deletes its cluster unless you set `KEEP=1`; then `kind delete cluster --name linkly-rehearsal`.
