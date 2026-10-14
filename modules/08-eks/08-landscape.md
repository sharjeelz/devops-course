# Landscape: running containers on AWS

> **You need:** Lessons 1–7 · **Time:** ~30 min · **Cost:** free (reading) · **Start from:** `checkpoint/08-eks`

## Why this matters

EKS is powerful and also the most work: you run add-ons, upgrades and node pools. AWS offers
several other ways to run the same containers, each trading control for less to manage.

## Concept

- **ECS (Elastic Container Service):** AWS's own orchestrator. No control-plane fee, simpler
  concepts (task definitions, services), deep AWS integration, AWS-only.
- **Fargate:** serverless capacity for ECS *or* EKS. No nodes to patch; you pay per pod/task
  CPU and memory. It costs more per unit and has fewer knobs (no DaemonSets on EKS Fargate).
- **App Runner:** give it an image, get an HTTPS URL with autoscaling. The least to manage, and
  the least control.
- **EKS Auto Mode:** EKS that also runs nodes (Karpenter), load balancers, storage and core
  add-ons for you, for an extra fee on the instances. It's much of this module, managed.
- **Lambda with container images:** for event-driven or spiky work rather than an always-on API.
- **Elsewhere:** GKE (Autopilot) and AKS are Google's and Microsoft's managed Kubernetes; the
  chart and Argo CD would move with few changes.
- **Tools you'll meet around EKS:**
  - `terraform-aws-modules/eks`: the community module that wraps what lesson 2 built by hand;
  - **AWS Load Balancer Controller**: ALBs and NLBs from Ingress/Service/Gateway objects;
  - **Karpenter**: node autoscaling (lesson 6);
  - **eksctl**: a CLI that creates clusters quickly (CloudFormation under the hood).

## Example

The same Linkly api as an ECS service, for comparison only (not run):

```json
{
  "family": "linkly-api",
  "requiresCompatibilities": ["FARGATE"],
  "networkMode": "awsvpc",
  "cpu": "256",
  "memory": "512",
  "containerDefinitions": [{
    "name": "api",
    "image": "ghcr.io/<you>/linkly-api:sha-abc1234",
    "portMappings": [{ "containerPort": 8000 }],
    "secrets": [{ "name": "DATABASE_URL", "valueFrom": "arn:aws:secretsmanager:...:secret:linkly-db-url" }]
  }]
}
```

Notice that ECS reads the secret itself (`valueFrom`), where on EKS External Secrets did that job.

## Lab

- [ ] Compare EKS, ECS on Fargate and App Runner for Linkly
- [ ] Name what EKS Auto Mode would remove from this module
- [ ] Decide which you'd choose for a small team, and say why

## Check yourself

1. A three-person startup runs one web API. EKS or ECS/App Runner?

<details><summary>Answer</summary>

Probably ECS on Fargate or App Runner: no cluster or nodes to look after, no control-plane fee.
EKS pays off with many services, a platform team, or a need for the Kubernetes ecosystem and portability.

</details>

2. What does Fargate remove, and what does it cost you?

<details><summary>Answer</summary>

It removes nodes: patching, sizing, scaling them. In exchange you pay more per vCPU/GB, start
pods a little slower, and give up node-level features such as DaemonSets and privileged pods.

</details>

## Clean up

This is the end of the expensive part:

```bash
AWS_REGION=<your region> app/linkly/eks/teardown.sh
```

It deletes Linkly's Argo CD Application (its finalizer removes the Gateway, and with it the load
balancer Kubernetes created), waits until no LoadBalancer Service is left, runs `terraform destroy`
(about 10–15 minutes; type yes), and finally lists anything tagged for the cluster that's still in
AWS. If it lists something, delete it in the EC2 console: it may still be billing.
