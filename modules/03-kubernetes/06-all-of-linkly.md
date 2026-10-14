# All of Linkly on Kubernetes

> **You need:** Lessons 1–5 · **Time:** ~90 min · **Start from:** `checkpoint/03-kubernetes`

## Why this matters

You've run every building block on its own. Now the whole of Linkly: two copies of the API
behind a Service, a worker, the web front door, with health checks deciding when a pod gets
traffic and limits stopping one pod from eating the node. Then you'll break it on purpose and
watch Kubernetes repair it.

## Concept

- **Readiness probe:** "can this pod take traffic yet?" Until it passes, the Service doesn't
  send it any. The API's is `GET /healthz`.
- **Liveness probe:** "is this pod still alive?" If it fails repeatedly, Kubernetes restarts the
  container. Only the API has one; a stuck worker shows up in its logs instead.
- **Requests and limits:** `requests` is what the scheduler reserves for the pod; a memory
  `limit` is a hard ceiling. Go over it and the container is killed (**OOMKilled**) and restarted.
- **`securityContext`:** `runAsNonRoot: true` makes Kubernetes refuse to start a container as
  root, and it can only check that when the image's `USER` is a *number*. That's why Linkly's
  Dockerfiles say `USER 10001`, and why the web image is built on `nginx-unprivileged` (uid 101).
  `allowPrivilegeEscalation: false` blocks gaining more rights later.
- **Start-up order: an init container.** Kubernetes starts everything at once. The API creates
  its table when it starts, so `40-api.yaml` has an **initContainer** that waits until Postgres
  answers. Without it, the API crashes a few times (`CrashLoopBackOff`, "failed to resolve host
  'postgres'": the name only exists once Postgres is ready) until Postgres catches up.
- **Restarting without dropping requests.** When a pod is replaced, it gets SIGTERM at the same
  moment the cluster starts removing it from its Service, and for a second or two traffic can
  still arrive at a pod that has stopped listening. The API's `preStop: sleep 5` keeps it serving
  until it's out of rotation, and nginx's `proxy_connect_timeout 2s` gives up fast instead of
  hanging on a pod that's gone.
- **Images in kind:** kind's node can't see your local Docker images, so `kind load docker-image`
  copies them in. With a `:dev` tag and `imagePullPolicy: IfNotPresent`, Kubernetes uses the
  loaded copy and doesn't try a registry. Module 4 pulls from GHCR instead.
- **The front door, for now:** the `web` Service is a **NodePort** (30080), and the repo's kind
  config maps it to `localhost:8080`.

## Example

```bash
cd app/linkly
for svc in api worker web; do
  docker build -t linkly-$svc:dev $svc
  kind load docker-image linkly-$svc:dev --name linkly
done
kubectl apply -f k8s/
kubectl -n linkly rollout status statefulset/postgres
for d in redis api worker web; do kubectl -n linkly rollout status deploy/$d; done
kubectl -n linkly get pods
```

Open http://localhost:8080: it's Linkly, on Kubernetes. Now break it while it's busy. In one
terminal, keep redirecting a link (replace `<code>`):

```bash
while true; do curl -s -o /dev/null -w '%{http_code} ' localhost:8080/r/<code>; sleep 0.3; done
```

In another, kill one API pod:

```bash
kubectl -n linkly delete pod $(kubectl -n linkly get pods -l app=api -o name | head -1 | cut -d/ -f2)
kubectl -n linkly get pods -l app=api -w          # a replacement appears; Ctrl+C to stop watching
```

The first terminal keeps printing `307`: the Service sends traffic to the other copy while the
new one starts and passes its readiness probe. Try a full rolling restart too,
`kubectl -n linkly rollout restart deploy/api`, with the loop still running.

Finally, the repo checks all of this for you. `k8s-smoke-test.sh` creates its *own* throwaway
cluster (so it doesn't touch yours), checks the API started without crashing, sends a
continuous stream of requests through a rolling restart and expects none to fail, deletes the
Postgres pod and checks the data, and deletes the cluster:

```bash
./k8s-smoke-test.sh            # ... K8S SMOKE TEST PASSED   (takes a few minutes)
```

## Lab

- [ ] Build the three images and load them into kind
- [ ] Apply every manifest and wait for the rollouts
- [ ] Use Linkly at localhost:8080
- [ ] Delete an API pod while redirecting links in a loop
- [ ] Do a rolling restart of the API while the loop runs
- [ ] Run the Kubernetes smoke test

## Check yourself

1. Readiness or liveness: which one stops traffic, and which one restarts the container?

<details><summary>Answer</summary>

A failing readiness probe takes the pod out of its Service (no traffic, no restart). A failing
liveness probe makes the kubelet restart the container.

</details>

2. A pod's status says `OOMKilled`. What happened?

<details><summary>Answer</summary>

It used more memory than its limit, and the kernel killed it. Kubernetes restarts it; if it keeps
happening, raise the limit or fix the memory use.

</details>

3. What would go wrong without the API's `preStop` sleep?

<details><summary>Answer</summary>

During a rolling restart, an old pod would stop listening while the Service was still sending it
traffic for a moment, so a few requests would fail with 502s. The pause keeps it serving until
it's been taken out of rotation.

</details>

4. Why does `imagePullPolicy: IfNotPresent` matter with kind?

<details><summary>Answer</summary>

The `:dev` images only exist inside the kind node (you loaded them). With `Always`, Kubernetes
would try to pull them from a registry, fail, and the pod would sit in `ImagePullBackOff`.

</details>
