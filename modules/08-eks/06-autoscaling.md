# Autoscaling

> **You need:** Lesson 4 · **Time:** ~60 min · **Cost:** included; briefly more if a third node starts (~$0.04/hour) · **Start from:** `checkpoint/08-eks`

## Why this matters

Traffic isn't flat. Sized for the peak, you pay for idle machines all night; sized for the
average, the peak takes you down. Autoscaling adds capacity when it's needed and removes it
after, on two levels: pods and nodes.

## Concept

- **HorizontalPodAutoscaler (HPA):** watches the api's CPU (from **metrics-server**) and changes
  the replica count between `minReplicas: 2` and `maxReplicas: 6` to keep average use around
  **70% of the CPU request**. Requests matter: the HPA's percentages are of what each pod
  *requested*, not of the node.
- **PodDisruptionBudget:** `maxUnavailable: 1` means voluntary disruptions (a node drain during an
  upgrade or scale-down) take at most one api pod at a time.
- **Node autoscaling:** when pods can't be scheduled (no room), something must add nodes:
  - **Cluster Autoscaler** grows and shrinks the node group between its min and max;
  - **Karpenter** picks and launches the best-fitting instances directly, faster and often cheaper;
  - **EKS Auto Mode** has AWS run Karpenter (and more) for you.
  This module's node group is fixed at 2–3 nodes; adding one of these is a stretch goal.

## Example

```bash
kubectl -n linkly get hpa api                     # TARGETS cpu: 3%/70%
kubectl top pods -n linkly                        # metrics-server at work

# Generate load from inside the cluster (and watch from a second terminal):
kubectl -n linkly run load --image=busybox:1.37 --restart=Never -- \
  sh -c 'while true; do wget -q -O /dev/null http://api:8000/healthz; done'
kubectl -n linkly get hpa api -w                  # CPU climbs, REPLICAS 2 → 3 → ...
kubectl -n linkly delete pod load                 # after ~5 minutes the HPA scales back down
```

Scale-down is deliberately slow (a 5-minute stabilisation window), so a brief lull doesn't remove
pods you'll need again a moment later.

## Lab

- [ ] Read the HPA's current CPU and target
- [ ] Load the api until the HPA adds pods
- [ ] Watch it scale back down after the load stops
- [ ] Explain what the PodDisruptionBudget protects against
- [ ] Explain the difference between Cluster Autoscaler and Karpenter

## Stretch

Install Karpenter on the cluster (its docs have a Terraform path) and watch it add a node when
you raise the HPA's `maxReplicas` beyond what two nodes hold.

## Check yourself

1. The HPA shows `<unknown>/70%`. What's missing?

<details><summary>Answer</summary>

CPU metrics: metrics-server isn't running or can't reach the kubelets, or the api pods have no
CPU request (a percentage of nothing can't be computed).

</details>

2. Why does the chart drop `replicas` from the api Deployment when autoscaling is on?

<details><summary>Answer</summary>

Otherwise every `helm upgrade` or Argo CD sync would reset the count to the fixed number,
fighting the HPA.

</details>
