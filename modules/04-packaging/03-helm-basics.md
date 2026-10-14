# Helm basics

> **You need:** Lesson 2 (and its clean-up) · **Time:** ~45 min · **Start from:** `checkpoint/04-packaging`

## Why this matters

Helm is how most software is installed on Kubernetes, from databases to monitoring stacks.
Before writing a chart, learn to *use* one: install it, see what it did, change it, and remove it
cleanly. Helm keeps track of every install, which is what makes the upgrades and rollbacks in
lesson 6 possible.

## Concept

- **Chart:** a package of templates plus default values (`app/linkly/helm/linkly/`).
- **Release:** one installed copy of a chart, with a name (`linkly`) in a namespace.
- **Revision:** every install, upgrade or rollback creates a new numbered revision of the release.
- **Values:** the settings a chart takes. Defaults live in `values.yaml`; you override them with
  `-f file.yaml` or `--set key=value`.
- **Where Helm keeps state:** in the release's namespace, as Secrets named
  `sh.helm.release.v1.<release>.v<revision>`. No server-side component is needed (Helm 2's
  "Tiller" is long gone). This course uses **Helm 4**.

## Example

```bash
cd app/linkly
helm install linkly helm/linkly -n linkly --create-namespace     # prints the chart's NOTES
kubectl -n linkly rollout status deploy/api
helm list -n linkly                       # linkly, revision 1, deployed, chart linkly-0.1.0
helm status linkly -n linkly              # the release and its notes again
helm get values linkly -n linkly          # what you overrode (nothing yet: null)
helm get manifest linkly -n linkly        # the exact YAML Helm applied
kubectl -n linkly get secrets -l owner=helm
```

Open http://localhost:8080: the same Linkly as Module 3, now installed as a Helm release. To remove it:

```bash
helm uninstall linkly -n linkly           # removes everything the release created
```

(The Postgres PersistentVolumeClaim stays behind, as StatefulSet volumes always do; delete it
with `kubectl -n linkly delete pvc data-postgres-0` if you want a truly fresh start.)

## Lab

- [ ] Install Linkly with Helm
- [ ] List releases and read the release status and notes
- [ ] See the values and the manifest Helm used
- [ ] Find the Secret where Helm keeps the release
- [ ] Uninstall Linkly and install it again

## Check yourself

1. What's the difference between a chart and a release?

<details><summary>Answer</summary>

A chart is the package (templates and defaults). A release is one installation of it, with a
name, in a namespace, with its own history of revisions. You can install the same chart many times.

</details>

2. Where does Helm keep a release's history?

<details><summary>Answer</summary>

In Secrets in the release's namespace, one per revision (`sh.helm.release.v1.linkly.v1`, `.v2`, …).
</details>
