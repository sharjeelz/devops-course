# Packaging: Helm and Kustomize

> **You need:** Module 3 · **Time:** ~8 hours · **Start from:** `checkpoint/04-packaging`

Module 3 left Linkly as seven plain YAML files. That works for one cluster. But the moment you
run it twice (your laptop and a production-like setup), you need different images, replica
counts, Services and passwords, and copying the YAML into a second folder and editing it by hand
is how environments drift apart. This module packages Linkly two ways the industry uses:
**Kustomize** (patch a base) and **Helm** (template a chart), then upgrades and rolls back
releases without dropping a request.

## Install

- **Helm** v4.3.0: download your platform's archive from the
  [Helm releases page](https://github.com/helm/helm/releases), check its `.sha256sum`, and put
  `helm` on your PATH (on Linux, `/usr/local/bin`). Check with `helm version`.
- **Kustomize** is already built into kubectl: `kubectl kustomize` and `kubectl apply -k`.

## Before you start

- **Bring in this module's files** from the end-of-module checkpoint (the chart, the Kustomize
  overlays, an updated smoke test, and a fix to Linkly's API that this module uncovered):

  ```bash
  git switch -c module-4 origin/checkpoint/04-packaging
  git checkout origin/checkpoint/05-gitops -- app/linkly .github
  git commit -m "Module 4 files"
  ```

  (No checkpoint branches in your fork? Use `upstream/` after
  `git remote add upstream https://github.com/sharjeelz/devops-course.git && git fetch upstream`.)
- **A clean cluster:** `kind delete cluster --name linkly` if Module 3's is still there, then
  `kind create cluster --name linkly --config app/linkly/kind-config.yaml`. Build and load the
  three `:dev` images as in Module 3, lesson 6.

Everything runs locally and costs nothing.

## Lessons

1. [Why packaging](01-why-packaging.md): one app, several environments
2. [Kustomize](02-kustomize.md): a base and overlays
3. [Helm basics](03-helm-basics.md): charts, releases, revisions
4. [Writing a chart](04-writing-a-chart.md): templates, values and helpers
5. [Environments](05-environments.md): dev and production-like values, pinned images
6. [Upgrades and rollbacks](06-upgrades-and-rollbacks.md): change it safely, undo it fast
7. [Landscape: packaging tools](07-landscape.md): OCI charts and the alternatives

By the end, `checkpoint/05-gitops` holds Linkly with its chart and overlays: where Module 5 starts.
