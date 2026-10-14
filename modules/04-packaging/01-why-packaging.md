# Why packaging

> **You need:** the module README's setup · **Time:** ~40 min · **Start from:** `checkpoint/04-packaging`

## Why this matters

Linkly on your laptop and Linkly in a production-like setup are the *same app* with a few
differences. If each environment gets its own hand-edited copy of the YAML, the copies drift: a
fix lands in one and not the other, and nobody can tell what really differs. Packaging tools keep
**one** description of the app and express each environment as a small, reviewable difference.

## Concept

What actually differs between Linkly's environments:

| | dev (kind) | production-like |
|---|---|---|
| Images | local `linkly-*:dev`, loaded into kind | `ghcr.io/<you>/linkly-*:sha-<commit>` from Module 2's pipeline |
| API replicas | 2 | 3 |
| Front door | NodePort 30080 | ClusterIP behind the Gateway API |
| Database password | a throwaway one | passed in at install time, never in Git |

Two approaches:

- **Patching (Kustomize):** keep plain, valid YAML as a **base**, and describe each environment
  as an **overlay** of changes ("this image instead", "3 replicas", "this field replaced").
  No template language; what you read is what you deploy.
- **Templating (Helm):** turn the YAML into **templates** with placeholders, filled from
  **values** files. More powerful (conditionals, loops, defaults, required settings), and it
  also manages installs as **releases** you can upgrade and roll back.

Many teams use both: Helm to install third-party software, Kustomize for their own apps, or
Kustomize on top of Helm's output.

## Example

Render the two environments without installing anything, and compare:

```bash
cd app/linkly
kubectl kustomize kustomize/dev  > /tmp/dev.yaml
kubectl kustomize kustomize/prod > /tmp/prod.yaml
diff /tmp/dev.yaml /tmp/prod.yaml
```

The differences are the first three rows of the table: the image names and tags, `replicas: 3`,
the web Service's `type` and `nodePort`, plus the `environment` label. The overlay is a sketch: it
doesn't handle the password, which mustn't be in Git at all (lesson 5 passes it at install time).

## Lab

- [ ] List what differs between Linkly's dev and production-like setups
- [ ] Render both Kustomize environments and compare them with diff
- [ ] Decide which differences you'd keep in Git and which must never be there

## Check yourself

1. Helm and Kustomize, in one sentence each?

<details><summary>Answer</summary>

Kustomize patches plain YAML: a base plus per-environment overlays, with no templating. Helm
fills templates from values files and installs the result as a versioned release you can
upgrade and roll back.

</details>

2. Which difference between environments must never be committed?

<details><summary>Answer</summary>

The production database password (and any other real secret). It's passed in at install time
now, and handled properly in Module 8.

</details>
