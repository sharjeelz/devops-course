# Landscape: GitOps and delivery tools

> **You need:** Lessons 1–6 · **Time:** ~40 min · **Start from:** `checkpoint/05-gitops`

## Why this matters

Argo CD is one way to do GitOps, and GitOps is one way to do delivery. You'll meet teams using
Flux, teams happily pushing from CI, and tools layered on top for safer rollouts. The ideas carry
over; knowing the options helps you pick, and fit in.

## Concept

- **Flux** (CNCF graduated, like Argo CD; v2.9 at the time of writing): a set of controllers,
  each for one job: `GitRepository` (fetch), `Kustomization` (apply), `HelmRelease` (install a
  chart), plus image automation that can update tags in Git itself. There's no built-in UI, and it's
  configured entirely through Kubernetes resources. Argo CD has a strong UI and the Application
  model; both reconcile from Git.
- **Push-based CD** is still common and fine for many teams: CI runs `helm upgrade` (Module 4)
  or `kubectl apply` with cluster credentials. It's simpler, but has no drift correction, and CI
  holds the keys.
- **Image update automation:** Argo CD Image Updater and Flux's image automation watch a registry
  and commit new tags to Git, which is what our deploy job does from CI.
- **Progressive delivery:** **Argo Rollouts** and **Flagger** replace a plain rolling update with
  canary or blue-green releases, shifting traffic gradually and checking metrics (Module 11)
  before going further.
- **Promotion tooling:** **Kargo** manages moving versions through environments (dev → staging →
  prod) on top of Argo CD.

## Example

The same Linkly deployment as a Flux `HelmRelease`, for comparison (not run):

```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata: { name: linkly, namespace: flux-system }
spec:
  url: https://github.com/<you>/devops-course
  ref: { branch: deploy }
  interval: 1m
---
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata: { name: linkly, namespace: linkly }
spec:
  interval: 5m
  chart:
    spec:
      chart: ./app/linkly/helm/linkly
      sourceRef: { kind: GitRepository, name: linkly, namespace: flux-system }
  valuesFiles: [./app/linkly/gitops/values.yaml]
```

## Lab

- [ ] Compare Argo CD and Flux in three points
- [ ] Explain when push-based CD is good enough
- [ ] Name one progressive delivery tool and what it adds

## Check yourself

1. What does progressive delivery add on top of a rolling update?

<details><summary>Answer</summary>

Control and evidence: send a small share of traffic to the new version first, check its error
rates and latency automatically, and only continue, or roll back on its own, based on the results.

</details>

2. When is push-based CD the better choice?

<details><summary>Answer</summary>

For small setups where one pipeline deploys one app and nobody edits the cluster by hand: fewer
moving parts. GitOps pays off as teams, clusters and environments multiply.

</details>
