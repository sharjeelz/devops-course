# Kustomize

> **You need:** Lesson 1, a clean `linkly` cluster with the `:dev` images loaded · **Time:** ~60 min · **Start from:** `checkpoint/04-packaging`

## Why this matters

Kustomize lets you keep Module 3's YAML exactly as it is and describe each environment as a
short list of changes. It's built into kubectl, so there's nothing to install, and a reviewer
can read an overlay in seconds.

## Concept

- **Base:** `app/linkly/k8s/` plus a file listing its resources. That file is named
  `Kustomization`, with no extension. Kustomize accepts that name, and `kubectl apply -f k8s/`
  (Module 3) skips it, because it only reads `.yaml`, `.yml` and `.json` files, so both ways keep working.
- **Overlay:** a folder whose `kustomization.yaml` points at the base and adds changes:
  - `images:`: swap image names and tags (`linkly-api` → `ghcr.io/<you>/linkly-api:sha-…`)
  - `replicas:`: change a Deployment's replica count
  - `labels:`: add a label to every object (`environment: prod`)
  - `patches:`: anything else. A **JSON patch** (`op: replace`/`remove`/`add` at a `path`) is
    precise: the prod overlay replaces the web Service's `type` and *removes* its `nodePort`,
    which a ClusterIP Service mustn't have.
- **Commands:** `kubectl kustomize <dir>` renders, `kubectl apply -k <dir>` applies, and
  `kubectl diff -k <dir>` shows what would change on the cluster.

## Example

```bash
cd app/linkly
cat kustomize/prod/kustomization.yaml        # the whole production difference, in one screen
kubectl kustomize kustomize/prod | grep -E "image:|replicas:|type:"
kubectl apply -k kustomize/dev
kubectl -n linkly rollout status deploy/api
kubectl -n linkly get deploy api -o jsonpath='{.metadata.labels.environment}'   # dev
```

Now change something and preview it before applying. Add this to the end of
`kustomize/dev/kustomization.yaml`:

```yaml
patches:
  - target:
      kind: Deployment
      name: worker
    patch: |-
      - op: replace
        path: /spec/template/spec/containers/0/resources/limits/memory
        value: 256Mi
```

```bash
kubectl diff -k kustomize/dev        # -  memory: 192Mi   +  memory: 256Mi
kubectl apply -k kustomize/dev
```

## Lab

- [ ] Render the prod overlay and find its three kinds of change
- [ ] Apply the dev overlay to your cluster
- [ ] Add a patch that changes the worker's memory limit
- [ ] Preview the change with kubectl diff before applying it

## Check yourself

1. What's the difference between a base and an overlay?

<details><summary>Answer</summary>

The base is the complete, plain description of the app. An overlay references the base and
lists only what's different for one environment; Kustomize combines them.

</details>

2. Why does the prod overlay use a JSON patch for the web Service instead of just changing `type`?

<details><summary>Answer</summary>

Changing `type` to ClusterIP isn't enough: the base also sets a `nodePort`, which isn't allowed
on a ClusterIP Service. A JSON patch can *remove* that field as well.

</details>

## Clean up

Revert your patch with `git checkout kustomize/dev/kustomization.yaml`, then `kubectl delete -k kustomize/dev`
so lesson 3 can install the same objects with Helm.
