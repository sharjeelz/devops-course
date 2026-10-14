# Self-healing

> **You need:** Lesson 3 (Linkly running under Argo CD) · **Time:** ~40 min · **Start from:** `checkpoint/05-gitops`

## Why this matters

A "quick fix" made by hand in production is how clusters drift away from what anyone wrote down,
until a rebuild or the next deploy silently undoes it. With selfHeal on, Argo CD treats Git as the
truth and puts back anything changed by hand. If a change matters, it goes through Git.

## Concept

- **Drift:** any difference between the cluster and Git.
- **`automated` sync:** when *Git* changes, apply it.
- **`selfHeal`:** when the *cluster* changes, put it back to match Git.
- **`prune`:** when something is *removed* from Git, delete it from the cluster too. Without
  prune, removed objects linger as orphans.
- Sync is automatic, but not instant: Argo CD checks Git about every three minutes, or at once
  when you press **Refresh** (or a webhook tells it). Cluster changes are seen within seconds.

## Example

Change the cluster by hand, and watch it come back:

```bash
kubectl -n linkly scale deploy/api --replicas=1
kubectl -n linkly get deploy api -w              # back to 2 within seconds; Ctrl+C
kubectl -n linkly delete service web
kubectl -n linkly get service web                # recreated, same NodePort
```

On the author's machine, both were back within about 4 seconds. In the UI, the application's
history shows the syncs Argo CD made to fix them.

Turn selfHeal off and try again:

```bash
kubectl -n argocd patch application linkly --type merge -p '{"spec":{"syncPolicy":{"automated":{"selfHeal":false}}}}'
kubectl -n linkly scale deploy/api --replicas=1
kubectl -n argocd get application linkly         # OutOfSync, and it stays that way
kubectl apply -f app/linkly/gitops/application.yaml   # selfHeal back on: it heals
```

## Lab

- [ ] Scale the API by hand and watch Argo CD undo it
- [ ] Delete the web Service and watch it come back
- [ ] Turn selfHeal off and see the drift stay
- [ ] Explain what prune would do if you deleted a template from the chart

## Check yourself

1. Someone needs more API replicas right now. What's the GitOps way?

<details><summary>Answer</summary>

Change `api.replicas` in Git (on `deploy` for this environment, or in the chart's values on
`main`) through a pull request. Scaling by hand would be undone, and wouldn't be recorded anywhere.

</details>

2. What happens to a Service you delete from the chart if `prune` is off?

<details><summary>Answer</summary>

It stays running in the cluster as an orphan, and Argo CD only flags it. With prune on, Argo CD
deletes it, so the cluster matches Git exactly.

</details>
