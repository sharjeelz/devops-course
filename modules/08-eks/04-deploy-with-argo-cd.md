# Deploy with Argo CD

> **You need:** Lessons 2–3, Module 5 (Argo CD and the deploy branch) · **Time:** ~75 min · **Cost:** included in the ~$0.25/hour · **Start from:** `checkpoint/08-eks`

## Why this matters

On kind, Argo CD deployed whatever CI put on the `deploy` branch. On EKS the idea doesn't change.
Only the values do: RDS instead of a local Postgres, HTTPS, autoscaling. A good delivery system
shouldn't care which cluster it's pointed at.

## Concept

- **The add-ons go first** (`app/linkly/eks/addons.sh`, the same script as lesson 1), then the
  two cluster-wide objects Linkly expects: the Secrets Manager store and the Let's Encrypt issuer.
- **`application-eks.yaml`** deploys the same chart from the same `deploy` branch, with three value
  files, later ones winning:
  1. `values-eks.yaml` (in the chart): RDS, HTTPS and autoscaling on;
  2. `gitops/values.yaml`: the image tag CI sets after every build (Module 5);
  3. `gitops/values-eks.yaml`: your database host, secret ARN and domain (none of them secret).
- **`ignoreDifferences` on the api's replicas:** the HPA changes them; without this, Argo CD would
  "correct" the HPA back on every sync.
- **The load balancer:** Envoy Gateway gives the Gateway a Service of type `LoadBalancer`, and EKS
  creates an AWS load balancer for it in the subnets tagged `kubernetes.io/role/elb`. Its DNS name
  is Linkly's front door. (For more control, NLBs and ALBs, the **AWS Load Balancer Controller**
  is the usual add-on; see lesson 8.)

## Example

```bash
app/linkly/eks/addons.sh
sed "s/AWS_REGION/$AWS_REGION/" app/linkly/eks/cluster-secret-store.yaml | kubectl apply -f -
# put your email in app/linkly/eks/cluster-issuer.yaml first (start with the staging server line)
kubectl apply -f app/linkly/eks/cluster-issuer.yaml

# Argo CD, as in Module 5:
kubectl create namespace argocd
kubectl apply -n argocd --server-side -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.5.5/manifests/install.yaml
```

Fill in `app/linkly/gitops/values-eks.yaml` from `terraform output` (and your domain), commit it to
main, and let CI carry it to `deploy`. Then:

```bash
kubectl apply -f app/linkly/gitops/application-eks.yaml        # repoURL: your fork
kubectl -n argocd get application linkly -w                    # Synced, Healthy
kubectl -n linkly get externalsecret linkly-db                 # SecretSynced
kubectl -n linkly get pods
kubectl -n envoy-gateway-system get svc -l gateway.envoyproxy.io/owning-gateway-name=linkly \
  -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'; echo
```

That last name is the load balancer. Linkly isn't reachable by it yet: the Gateway only answers
for your domain, and the certificate needs DNS (lesson 5). You can check the routing already, by
telling the load balancer which name you mean:

```bash
curl -sI -H 'Host: linkly.<your domain>' http://<that name>/ | head -3    # 301 to https://linkly.<your domain>/
```

## Lab

- [ ] Install the add-ons, the secret store and the issuer on EKS
- [ ] Deploy Linkly with Argo CD from the deploy branch
- [ ] Confirm the database Secret came from Secrets Manager
- [ ] Find the load balancer AWS created for the Gateway
- [ ] Push a change to main and watch it reach EKS

## Check yourself

1. Where does the image tag on EKS come from, and why is that the same file as on kind?

<details><summary>Answer</summary>

From `gitops/values.yaml` on the deploy branch, set by CI after each build of main. Both
Applications read it, so one pipeline promotes the same build everywhere.

</details>

2. Why would Argo CD and the HPA fight without `ignoreDifferences`?

<details><summary>Answer</summary>

The HPA sets `spec.replicas`; Argo CD sees a difference from Git and, with self-heal, sets it
back. They'd keep undoing each other. (The chart also leaves `replicas` out when autoscaling is
on, so Git doesn't state a number at all.)

</details>
