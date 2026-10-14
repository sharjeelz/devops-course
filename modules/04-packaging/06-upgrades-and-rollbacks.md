# Upgrades and rollbacks

> **You need:** Lesson 5 (Linkly installed with Helm, reachable on a port) · **Time:** ~60 min · **Start from:** `checkpoint/04-packaging`

## Why this matters

Deploying is the moment things break. The two questions that matter are "can we change it
without users noticing?" and "when a change is bad, how fast can we undo it?". With Module 3's
probes and preStop, and Helm's revision history, the answers are "yes" and "one command".

## Concept

- **`helm upgrade`** applies a new revision: new values, a new chart version, a new image.
  Kubernetes rolls the changed Deployments pod by pod, and readiness probes and the preStop pause
  keep requests flowing.
- **Revision history:** `helm history linkly` lists every revision and how it ended.
- **`helm rollback linkly <revision>`** re-applies an earlier revision's exact manifests, as a
  new revision.
- **A bad image doesn't take the site down.** A Deployment only replaces old pods once new ones
  are ready. A new pod that can't pull its image (`ErrImagePull`) never becomes ready, so the old
  pods keep serving, but the upgrade is stuck half-done until you act.
- **Let Helm notice for you:** `--wait --timeout 60s` makes Helm wait for everything to be ready.
  With **`--rollback-on-failure`** (Helm 4's name for the old `--atomic`), a failed upgrade is
  rolled back automatically, and Helm turns waiting on by itself when you use it.

## Example

Use Linkly in one terminal while you change it in another. Keep redirecting a link (lesson 5's
port-forward on 8081, or `localhost:8080` with the dev values; replace `<code>`):

```bash
while true; do curl -s -o /dev/null -w '%{http_code} ' localhost:8081/r/<code>; sleep 0.2; done
```

A good upgrade, under load. Changing `baseUrl` changes the config checksum, so every api and
worker pod is replaced one by one: a real rolling update.

```bash
helm upgrade linkly app/linkly/helm/linkly -n linkly --reuse-values --set baseUrl=http://localhost:9999 --wait
helm history linkly -n linkly
kubectl -n linkly get pods                # new api and worker pods; postgres-0 untouched
```

The loop keeps printing `307`. On the author's machine, 130 requests (half of them creating new
links) went through this upgrade and none failed.

A bad upgrade, made on purpose:

```bash
helm upgrade linkly app/linkly/helm/linkly -n linkly --reuse-values --set image.tag=does-not-exist
kubectl -n linkly get pods                # 3 old api pods Running, 1 new ErrImagePull; web and worker one each too
```

The loop *still* prints `307`, because the old pods never stopped. Helm reported success anyway,
because it didn't wait. Roll back to the last good revision:

```bash
helm history linkly -n linkly             # find the revision before the bad one
helm rollback linkly <that revision> -n linkly --wait
```

And let Helm catch it next time:

```bash
helm upgrade linkly app/linkly/helm/linkly -n linkly --reuse-values --set image.tag=does-not-exist \
  --rollback-on-failure --wait --timeout 60s
helm history linkly -n linkly             # "failed", then "Rollback to …" by itself
```

## Lab

- [ ] Upgrade Linkly while requests keep flowing
- [ ] Read the release history
- [ ] Make a bad upgrade on purpose and see what keeps serving
- [ ] Roll back and confirm the fix
- [ ] Let --rollback-on-failure undo a bad upgrade by itself

## Check yourself

1. Why didn't a nonexistent image tag take the site down?

<details><summary>Answer</summary>

A rolling update only removes old pods after new ones are ready. The new pod never pulled its
image, so it never became ready, and the old pods kept serving.

</details>

2. What does `--rollback-on-failure` do, and why does it involve waiting?

<details><summary>Answer</summary>

If the upgrade fails, Helm rolls back to the previous good revision automatically. It can only
notice a failure by waiting for the resources to become ready, so Helm 4 switches waiting on
whenever this flag is set (`--wait` is still fine to write).

</details>

3. What does `helm rollback` actually do?

<details><summary>Answer</summary>

It re-applies the manifests stored for an earlier revision, recorded as a new revision. Nothing
is deleted from the history, so you can see exactly what happened.

</details>
