# ConfigMaps and Secrets

> **You need:** Lesson 3 · **Time:** ~45 min · **Start from:** `checkpoint/03-kubernetes`

## Why this matters

In Compose, Linkly's settings sat in `compose.yaml`. In Kubernetes, settings live in their own
objects, so the same image runs anywhere and only the configuration changes between
environments. Credentials go in a separate kind of object, so they can be guarded differently.

## Concept

- **ConfigMap:** plain key-value settings (`REDIS_URL`, `BASE_URL`).
- **Secret:** the same idea for sensitive values (`DATABASE_URL`, the Postgres password).
  Access to Secrets can be restricted separately, and they're never shown by `kubectl describe`.
- **Using them:** `envFrom` turns every key into an environment variable; `valueFrom.secretKeyRef`
  picks one key. Linkly's manifests use both.
- **A Secret is base64, not encryption.** Anyone who can read the object, or the YAML file in
  Git, can read the password. That's fine for a local cluster with a throwaway password,
  and never fine for real credentials. Module 8 keeps real secrets out of Git.
- **Changes don't reach running pods.** Environment variables are read when a container
  starts. After changing config, restart the pods: `kubectl rollout restart`.

## Example

```bash
kubectl apply -f app/linkly/k8s/10-config.yaml
kubectl -n linkly get configmap linkly-config -o yaml
kubectl -n linkly get secret linkly-db -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d   # linkly
```

The Secret file uses `stringData`, so you write plain values and Kubernetes stores them base64-encoded.

Config changes and restarts, shown with a throwaway Deployment that reads the ConfigMap:

```bash
kubectl -n linkly create deployment env-demo --image=busybox:1.36 -- sh -c 'sleep 3600'
kubectl -n linkly set env deployment/env-demo --from=configmap/linkly-config
kubectl -n linkly rollout status deploy/env-demo
kubectl -n linkly exec deploy/env-demo -- printenv BASE_URL     # http://localhost:8080

kubectl -n linkly patch configmap linkly-config --type merge -p '{"data":{"BASE_URL":"http://localhost:9999"}}'
kubectl -n linkly exec deploy/env-demo -- printenv BASE_URL     # still http://localhost:8080
kubectl -n linkly rollout restart deploy/env-demo
kubectl -n linkly rollout status deploy/env-demo
kubectl -n linkly exec deploy/env-demo -- printenv BASE_URL     # http://localhost:9999
```

Clean up: `kubectl -n linkly delete deploy env-demo` and `kubectl apply -f app/linkly/k8s/10-config.yaml`
to put the setting back. Linkly's own pods work the same way.

## Lab

- [ ] Apply the ConfigMap and Secret
- [ ] Read the Postgres password back out of the Secret
- [ ] Change a ConfigMap value and show running pods only see it after a restart
- [ ] Explain why the Secret file must not hold a real password

## Check yourself

1. Is a Kubernetes Secret encrypted?

<details><summary>Answer</summary>

Not by default. It's base64-encoded, which anyone can decode. Clusters can encrypt Secrets at
rest in etcd, and access can be limited, but the YAML in Git is plain readable text.

</details>

2. You changed a ConfigMap. Why does the app still use the old value, and what do you do?

<details><summary>Answer</summary>

Environment variables are set when the container starts. `kubectl rollout restart deploy/<name>`
replaces the pods one by one, and the new ones read the new value.

</details>
