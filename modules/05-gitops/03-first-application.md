# Your first Application

> **You need:** Lesson 2, and the `deploy` branch in your fork (module README) · **Time:** ~45 min · **Start from:** `checkpoint/05-gitops`

## Why this matters

One small YAML file tells Argo CD to deploy Linkly from your repository and keep it that way. After
you apply it, you never deploy Linkly by hand again.

## Concept

An **Application** (`app/linkly/gitops/application.yaml`) has:

- **source:** where the manifests come from. Here: your repo, branch **`deploy`**, the Helm
  chart at `app/linkly/helm/linkly`, plus the values file `../../gitops/values.yaml` (relative to
  the chart, so `app/linkly/gitops/values.yaml`) that says which images this environment runs.
- **destination:** which cluster and namespace (this cluster, `linkly`).
- **project:** a group with its own rules (`default` is fine here).
- **syncPolicy:** `automated` (sync whenever Git changes), with `prune` and `selfHeal`
  (lesson 4), and `CreateNamespace=true`.

Why the **`deploy` branch** and not `main`? `deploy` is `main` plus one thing: which image tag
runs. CI keeps it up to date (lesson 5), so its history is your deployment log, and `main` stays
protected by the checks from Module 2.

Argo CD shows two statuses:

- **Sync status:** does the cluster match Git? (`Synced` / `OutOfSync`)
- **Health status:** is what's running actually working? (`Healthy` / `Progressing` / `Degraded`),
  based on rollouts and readiness.

## Example

```bash
kubectl apply -f app/linkly/gitops/application.yaml
kubectl -n argocd get application linkly -w      # Ctrl+C once it says Synced / Healthy
kubectl -n linkly get pods
kubectl -n linkly get deploy api -o jsonpath='{.spec.template.spec.containers[0].image}'; echo
```

Open http://localhost:8080. It's Linkly, running *your* pipeline's images, and nobody ran
`helm install`. In the Argo CD UI, click the `linkly` application to see every object it created,
its health, and which Git commit it's synced to.

## Lab

- [ ] Point the Application at your fork and apply it
- [ ] Find the sync status and the health status
- [ ] Find which Git commit Argo CD is synced to
- [ ] Open Linkly deployed by Argo CD

## Check yourself

1. "Synced but Degraded": what does that mean?

<details><summary>Answer</summary>

The cluster matches Git exactly, but what Git describes isn't working (for example, pods crash or
an image can't be pulled). The problem is in what you committed, not in the sync.

</details>

2. Why does the Application read the values file from the `deploy` branch rather than `main`?

<details><summary>Answer</summary>

`deploy` records which image actually runs; CI updates it after every good build of `main`.
Keeping that out of `main` means CI never pushes to the protected branch, and `deploy`'s history
is a clean log of every deployment.

</details>
