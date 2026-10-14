# Landscape: packaging tools

> **You need:** Lessons 1–6 · **Time:** ~40 min · **Start from:** `checkpoint/04-packaging`

## Why this matters

You'll install other people's charts all the time, and you'll meet teams using tools other than
Helm and Kustomize. Knowing where charts come from, how they're shared, and what else exists
helps you pick well, and avoid depending on something that changes under you.

## Concept

- **Helm's history:** Helm 2 needed **Tiller**, a component inside the cluster with broad
  permissions. Helm 3 (2019) removed it, storing releases as Secrets as you saw. **Helm 4**
  (late 2025) modernised it further, renaming some flags (`--rollback-on-failure`,
  `--force-replace`) and changing how it waits for resources.
- **Charts as OCI artifacts:** charts can live in container registries, next to your images:
  `helm package` makes a `.tgz`, and `helm push` sends it to `oci://ghcr.io/<you>/charts`.
  Installing is then `helm install linkly oci://ghcr.io/<you>/charts/linkly --version 0.1.0`.
- **Public charts:** most software ships a chart, but check who maintains it and where its
  *images* come from. Catalogs have changed their terms and image availability before, and a
  chart you depend on can quietly stop working.
- **Other tools:**
  - **cdk8s:** write Kubernetes objects in TypeScript, Python or Go, and generate YAML.
  - **Jsonnet / Tanka:** a data templating language popular at large scale.
  - **Timoni** (CUE) and **Carvel ytt:** typed or structured configuration with validation.
- **Choosing:** Kustomize for your own apps when the differences are small. Helm when you need
  logic, defaults and releases, or you're distributing software for others to install. A
  code-based tool when your team would rather write a program than YAML.

## Example

```bash
helm package app/linkly/helm/linkly       # Successfully packaged chart ... linkly-0.1.0.tgz
```

Sharing it through GHCR would be (not run here; it needs a token with `write:packages`):

```bash
helm registry login ghcr.io -u <you>
helm push linkly-0.1.0.tgz oci://ghcr.io/<you>/charts
```

## Lab

- [ ] Package the chart into a .tgz
- [ ] Explain when you'd pick Kustomize over Helm
- [ ] Name one tool that generates Kubernetes manifests from code

## Check yourself

1. What is an "OCI chart"?

<details><summary>Answer</summary>

A Helm chart stored in a container registry as an OCI artifact, so it's versioned, pulled and
access-controlled the same way as your images, without a separate chart repository server.

</details>

2. Why was removing Tiller a big deal?

<details><summary>Answer</summary>

Tiller ran inside the cluster with wide permissions that every Helm user effectively borrowed.
Without it, Helm acts with *your* own permissions, and release state lives in ordinary Secrets.

</details>
