# Environments

> **You need:** Lesson 4 · **Time:** ~75 min · **Start from:** `checkpoint/04-packaging`

## Why this matters

The point of packaging is running the same app in different places. Here you install Linkly the
production-like way: images built and tested by your Module 2 pipeline, pinned to one exact
build, three API replicas, and traffic through the Gateway API instead of a NodePort.

## Concept

- **A values file per environment.** `values.yaml` holds the defaults (dev), and
  `values-prod.yaml` holds only what's different. Helm merges them: `-f values-prod.yaml`.
- **`--set` for things that differ per install** (the exact image tag) or that must never be in
  Git (the password).
- **Pin images by build.** `image.tag` takes the `sha-<commit>` tag from Module 2, so you know
  exactly which code is running. The prod values leave `tag` and `postgres.password` empty, and
  the chart's `required` makes the install fail with a clear message rather than deploying
  something wrong.
- **The Gateway needs a GatewayClass**, which is cluster infrastructure, so it's not part of the
  app's chart. Install the Gateway API implementation and its class first, then the chart's
  Gateway and HTTPRoute attach to it.
- **Change `image.prefix`** in `values-prod.yaml` (and `newName` in the Kustomize prod overlay)
  to *your* GHCR namespace, so you deploy your own builds.

## Example

Start fresh, and install Envoy Gateway with its GatewayClass (Module 3, lesson 7):

```bash
cd app/linkly
helm uninstall linkly -n linkly; kubectl delete namespace linkly
kubectl apply --server-side -f https://github.com/envoyproxy/gateway/releases/download/v1.9.2/install.yaml
kubectl -n envoy-gateway-system wait --for=condition=Available deployment/envoy-gateway --timeout=300s
kubectl apply -f - <<'EOF'
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: eg
spec:
  controllerName: gateway.envoyproxy.io/gatewayclass-controller
EOF
```

Try the prod values without the two required settings first: the chart refuses, one at a time,
telling you what's missing and how to pass it.

```bash
helm template t helm/linkly -f helm/linkly/values-prod.yaml
# Error: ... postgres.password is required: pass one at install time, e.g. --set-string postgres.password=<letters and digits>
helm template t helm/linkly -f helm/linkly/values-prod.yaml --set-string postgres.password=x
# Error: ... image.tag is required: pin an exact image, e.g. --set image.tag=sha-abc1234
```

The password may contain letters, digits and `_` only (it goes into a URL), and `--set-string`
keeps an all-digit password as text.

Now install, with a tag from your packages page on GitHub (`sha-…`) and a password of your own:

```bash
helm install linkly helm/linkly -n linkly --create-namespace \
  -f helm/linkly/values-prod.yaml --set image.tag=sha-<your build> --set-string postgres.password=<letters and digits>
kubectl -n linkly rollout status deploy/api
kubectl -n linkly get pods -l app=api -o jsonpath='{range .items[*]}{.spec.containers[0].image}{"\n"}{end}'
kubectl -n linkly wait --for=condition=Accepted gateway/linkly
svc=$(kubectl -n envoy-gateway-system get svc -l gateway.envoyproxy.io/owning-gateway-name=linkly -o jsonpath='{.items[0].metadata.name}')
kubectl -n envoy-gateway-system port-forward "svc/$svc" 8081:80
```

(If the last command says the Service isn't there yet, wait a few seconds and run the `svc=` line again.)

Open http://localhost:8081: three API pods running your pipeline's images, reached through the
Gateway. Compare with the Kustomize prod overlay, `kubectl kustomize kustomize/prod`. It makes
the same image, replica and Service changes, but it's a simpler sketch: it keeps the base's local
password and has no Gateway, so on its own it has no front door.

## Lab

- [ ] Try the prod values without a password or image tag and read both errors
- [ ] Install the prod values with your own GHCR images
- [ ] Reach Linkly through the Gateway
- [ ] Compare the Helm prod render with the Kustomize prod overlay

## Check yourself

1. Why does the chart *require* an image tag in production instead of defaulting to one?

<details><summary>Answer</summary>

A default would quietly deploy something nobody chose. Requiring it means every production
install names exactly which build runs, so it's traceable to a commit and repeatable.

</details>

2. Which settings belong in `values-prod.yaml`, and which on the command line?

<details><summary>Answer</summary>

Stable environment differences (replicas, Service type, Gateway on, image prefix) go in the file,
reviewed in Git. Per-deploy choices (the exact tag) and secrets (the password) go in at install
time; secrets never belong in the repo.

</details>
