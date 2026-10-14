# Installing Argo CD

> **You need:** Lesson 1, a `linkly` kind cluster · **Time:** ~45 min · **Start from:** `checkpoint/05-gitops`

## Why this matters

Argo CD is the agent that will run your deployments from now on. It lives in its own namespace,
has a web UI that shows every object it manages and its health, and runs entirely inside the
cluster. That's the point of pull-based deployment.

## Concept

The pods you'll see in `argocd`:

| Pod | What it does |
|---|---|
| `argocd-server` | the API and the web UI |
| `argocd-repo-server` | clones Git repositories and renders manifests (Helm, Kustomize, plain YAML) |
| `argocd-application-controller` | compares rendered manifests with the cluster, and syncs them |
| `argocd-applicationset-controller` | generates many Applications from a template (lesson 6) |
| `argocd-redis` | a cache |
| `argocd-dex-server` | single sign-on (unused here) |
| `argocd-notifications-controller` | sends notifications about syncs (unused here) |

Argo CD's own resource types (CRDs) include **Application**, its unit of deployment: "render
*this* from *that* Git repo and keep it in *this* namespace" (next lesson).

## Example

```bash
kubectl create namespace argocd
kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.5.5/manifests/install.yaml
kubectl -n argocd rollout status deploy/argocd-server
kubectl -n argocd get pods
```

(`--server-side` is needed because Argo CD's CRDs are too big for the annotation a normal
`kubectl apply` keeps.)

The first admin password is generated into a Secret:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
kubectl -n argocd port-forward svc/argocd-server 8443:443
```

Open https://localhost:8443 and log in as `admin` with that password. The browser warns about the
certificate, because Argo CD made its own; accept it for this local cluster.

## Lab

- [ ] Install Argo CD in your cluster
- [ ] Find the initial admin password
- [ ] Log in to the Argo CD UI
- [ ] Name what each Argo CD pod does

## Check yourself

1. Which Argo CD component actually talks to Git, and which one changes the cluster?

<details><summary>Answer</summary>

The repo-server clones repositories and renders the manifests; the application-controller
compares them with the cluster and applies the differences.

</details>

2. Why is installing Argo CD from a pinned version URL (`v3.5.5`) better than "latest"?

<details><summary>Answer</summary>

The same command installs the same thing tomorrow. "Latest" could bring a new major version,
with changed defaults, in the middle of a course or an outage.

</details>
