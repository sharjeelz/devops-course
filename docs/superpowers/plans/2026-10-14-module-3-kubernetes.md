# Module 3 (Kubernetes Core) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Linkly runs on a local Kubernetes cluster (kind), described as plain manifests: Deployments, Services, a ConfigMap and Secret, a StatefulSet with storage for Postgres, probes and resource limits. A Kubernetes smoke test proves it works. The front door moves to the Gateway API (ingress-nginx was retired in March 2026). Eight lessons teach it piece by piece.

**Architecture:**
- **Manifests:** `app/linkly/k8s/` holds one file per component, all in namespace `linkly`. Applying the folder with `kubectl apply -f app/linkly/k8s/` works, and files are numbered so the namespace and config come first.
- **Images:** built locally as `linkly-<svc>:dev` and loaded into kind with `kind load docker-image`. Pulling from GHCR comes with Helm values in Module 4.
- **Front door:** the `web` Service is a NodePort (30080), which `app/linkly/kind-config.yaml` maps to the host's `8080`.
- **Gateway API:** `app/linkly/k8s/gateway/` holds a Gateway and HTTPRoute, used with Envoy Gateway v1.9.2 in lesson 7 only.
- **Smoke test:** `app/linkly/k8s-smoke-test.sh` creates a throwaway kind cluster with its own name and port, builds and loads the images, applies the manifests, runs the same user-level checks as the Compose smoke test plus Kubernetes ones (self-healing, data surviving a pod deletion, non-root), and deletes the cluster.

**Tech Stack:** kind v0.33.0, kubectl 1.36, Kubernetes (kind's default node image), Envoy Gateway v1.9.2, Gateway API v1.

**Spec:** `docs/superpowers/specs/2026-10-14-course-design.md`, module map row 3: "Deployments, Services, ConfigMaps/Secrets, StatefulSet for Postgres, Ingress/Gateway API (kind); landscape: Swarm, Nomad".

## Global Constraints

- **Lesson format:** the format rules are unchanged, and every lesson header starts from `checkpoint/03-kubernetes`.
- **Kubernetes contexts:** every `kubectl` call in the smoke test passes `--context kind-<cluster>`, so a learner's other clusters are never touched. Lessons use the kind context that kind sets as current.
- **Images:** no `:latest` tags. Local images are tagged `:dev` with `imagePullPolicy: IfNotPresent`, and nothing pulls them from a registry.
- **Hardening:** every Linkly container runs as non-root with `allowPrivilegeEscalation: false`, and has requests and limits plus readiness probes. The api also has a liveness probe.
- **Secrets:** database credentials live only in the Secret manifest. Lesson 4 says plainly that a Secret is base64, not encryption, and that real secrets don't belong in Git; Module 8 replaces this.
- **Cost:** everything runs locally and costs nothing. Clean up with `kind delete cluster --name linkly`.
- **Commits** end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **Postgres pod rescheduled or deleted.** The data must survive, because it is on a PVC. Pinned in Task 2 (smoke: delete the postgres pod, and the link still redirects).
2. **An API pod killed mid-traffic.** The Deployment replaces it and the Service routes to the healthy replica. Pinned in Task 2 (smoke: delete one api pod, requests keep working, and the replica count is restored).
3. **The worker starting before Postgres is ready, or the API before its table exists.** Readiness probes plus the worker's retry must cope without CrashLoopBackOff spirals. Pinned in Task 2 (the smoke test applies everything at once).
4. **A learner's own cluster or port 8080 in use.** The smoke test uses its own cluster name and port, and pins `--context`. Pinned in Task 2.
5. **Postgres on a fresh volume.** `lost+found` in the mount root breaks initdb, so `PGDATA` must point at a subdirectory. Pinned in Task 1.

---

### Task 1: Manifests and kind config

**Files:** create the following under `app/linkly/`:
- `kind-config.yaml`
- `k8s/00-namespace.yaml`
- `k8s/10-config.yaml`
- `k8s/20-postgres.yaml`
- `k8s/30-redis.yaml`
- `k8s/40-api.yaml`
- `k8s/50-worker.yaml`
- `k8s/60-web.yaml`

`kind-config.yaml`:

```yaml
# A one-node kind cluster whose NodePort 30080 (Linkly's web Service) is reachable at localhost:8080.
#   kind create cluster --name linkly --config kind-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    extraPortMappings:
      - containerPort: 30080
        hostPort: 8080
```

`k8s/00-namespace.yaml`:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: linkly
```

`k8s/10-config.yaml`:

```yaml
# Settings every Linkly part reads. The ConfigMap holds plain settings; the Secret holds the
# database credentials. A Secret is only base64-encoded, not encrypted: fine for a local cluster,
# never for real credentials in Git (Module 8 fixes that).
apiVersion: v1
kind: ConfigMap
metadata:
  name: linkly-config
  namespace: linkly
data:
  REDIS_URL: redis://redis:6379/0
  BASE_URL: http://localhost:8080
---
apiVersion: v1
kind: Secret
metadata:
  name: linkly-db
  namespace: linkly
type: Opaque
stringData:
  POSTGRES_USER: linkly
  POSTGRES_PASSWORD: linkly
  POSTGRES_DB: linkly
  DATABASE_URL: postgresql://linkly:linkly@postgres:5432/linkly
```

`k8s/20-postgres.yaml`:

```yaml
# Postgres as a StatefulSet: a stable name (postgres-0) and its own disk (a PersistentVolumeClaim)
# that outlives the pod.
apiVersion: v1
kind: Service
metadata:
  name: postgres
  namespace: linkly
spec:
  clusterIP: None            # "headless": the name resolves straight to the pod
  selector:
    app: postgres
  ports:
    - port: 5432
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
  namespace: linkly
spec:
  serviceName: postgres
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
        - name: postgres
          image: postgres:16-alpine
          envFrom:
            - secretRef:
                name: linkly-db
          env:
            - name: PGDATA                       # a subfolder: a new volume's root has lost+found in it
              value: /var/lib/postgresql/data/pgdata
          ports:
            - containerPort: 5432
          readinessProbe:
            exec:
              command: ["pg_isready", "-U", "linkly", "-d", "linkly"]
            periodSeconds: 3
          resources:
            requests: { cpu: 50m, memory: 128Mi }
            limits: { memory: 512Mi }
          volumeMounts:
            - name: data
              mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: 1Gi
```

`k8s/30-redis.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: redis
  namespace: linkly
spec:
  selector:
    app: redis
  ports:
    - port: 6379
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
  namespace: linkly
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
        - name: redis
          image: redis:7-alpine
          ports:
            - containerPort: 6379
          readinessProbe:
            exec:
              command: ["redis-cli", "ping"]
            periodSeconds: 3
          resources:
            requests: { cpu: 25m, memory: 32Mi }
            limits: { memory: 128Mi }
```

`k8s/40-api.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: api
  namespace: linkly
spec:
  selector:
    app: api
  ports:
    - port: 8000
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  namespace: linkly
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
    spec:
      securityContext:
        runAsNonRoot: true
      containers:
        - name: api
          image: linkly-api:dev
          imagePullPolicy: IfNotPresent
          envFrom:
            - configMapRef:
                name: linkly-config
          env:
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef: { name: linkly-db, key: DATABASE_URL }
          ports:
            - containerPort: 8000
          readinessProbe:                  # only send traffic once it answers
            httpGet: { path: /healthz, port: 8000 }
            periodSeconds: 3
          livenessProbe:                   # restart it if it stops answering
            httpGet: { path: /healthz, port: 8000 }
            initialDelaySeconds: 10
            periodSeconds: 10
          resources:
            requests: { cpu: 50m, memory: 96Mi }
            limits: { memory: 256Mi }
          securityContext:
            allowPrivilegeEscalation: false
```

`k8s/50-worker.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: worker
  namespace: linkly
spec:
  replicas: 1
  selector:
    matchLabels:
      app: worker
  template:
    metadata:
      labels:
        app: worker
    spec:
      securityContext:
        runAsNonRoot: true
      terminationGracePeriodSeconds: 15
      containers:
        - name: worker
          image: linkly-worker:dev
          imagePullPolicy: IfNotPresent
          envFrom:
            - configMapRef:
                name: linkly-config
          env:
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef: { name: linkly-db, key: DATABASE_URL }
          resources:
            requests: { cpu: 25m, memory: 64Mi }
            limits: { memory: 192Mi }
          securityContext:
            allowPrivilegeEscalation: false
```

`k8s/60-web.yaml`:

```yaml
# The front door. A NodePort Service: kind maps node port 30080 to localhost:8080 (kind-config.yaml).
# Lesson 7 puts the Gateway API in front instead.
apiVersion: v1
kind: Service
metadata:
  name: web
  namespace: linkly
spec:
  type: NodePort
  selector:
    app: web
  ports:
    - port: 8080
      targetPort: 8080
      nodePort: 30080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: linkly
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
        - name: web
          image: linkly-web:dev
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 8080
          readinessProbe:
            httpGet: { path: /, port: 8080 }
            periodSeconds: 3
          resources:
            requests: { cpu: 25m, memory: 32Mi }
            limits: { memory: 128Mi }
```

- [ ] **Step 1: Validate.** Run `kubectl apply --dry-run=client -f app/linkly/k8s/`. Expected: every object is "created (dry run)" with no errors.
- [ ] **Step 2: Commit.** Message: `feat(linkly): Kubernetes manifests and a kind cluster config`.

### Task 2: Kubernetes smoke test (TDD: watch it fail, then make it pass)

**Files:** create `app/linkly/k8s-smoke-test.sh` (executable).

```bash
#!/usr/bin/env bash
# Creates a throwaway kind cluster, builds and loads Linkly's images, applies app/linkly/k8s/,
# uses Linkly through its front door like a person would, checks Kubernetes keeps it running
# (pods replaced, data kept), then deletes the cluster.
# Usage: ./k8s-smoke-test.sh     (own cluster name and port; LINKLY_PORT=18099 if 18090 is taken)
set -euo pipefail
cd "$(dirname "$0")"
cluster="${CLUSTER:-linkly-smoke}"
export LINKLY_PORT="${LINKLY_PORT:-18090}"
base="http://localhost:${LINKLY_PORT}"
k() { kubectl --context "kind-${cluster}" -n linkly "$@"; }

fail() { echo "K8S SMOKE TEST FAILED: $*" >&2; k get pods -o wide >&2 || true; k get events --sort-by=.lastTimestamp 2>/dev/null | tail -15 >&2 || true; exit 1; }
cleanup() { kind delete cluster --name "$cluster" >/dev/null 2>&1 || true; rm -f "$cfg"; }
cfg=$(mktemp)
trap cleanup EXIT

echo "== cluster"
sed "s/hostPort: 8080/hostPort: ${LINKLY_PORT}/" kind-config.yaml > "$cfg"
kind create cluster --name "$cluster" --config "$cfg" --wait 120s >/dev/null 2>&1 || fail "kind could not create the cluster"

echo "== images"
for svc in api worker web; do
  docker build -q -t "linkly-${svc}:dev" "$svc" >/dev/null || fail "build $svc"
  kind load docker-image "linkly-${svc}:dev" --name "$cluster" >/dev/null 2>&1 || fail "load $svc"
done

echo "== apply and wait"
kubectl --context "kind-${cluster}" apply -f k8s/ >/dev/null || fail "apply"
k rollout status statefulset/postgres --timeout=180s >/dev/null || fail "postgres not ready"
for d in redis api worker web; do k rollout status "deployment/$d" --timeout=180s >/dev/null || fail "$d not ready"; done

echo "== containers don't run as root"
for d in api worker; do
  [ "$(k exec "deploy/$d" -- id -u | tr -d '\r')" != "0" ] || fail "$d runs as root"
done

echo "== shorten, redirect, count (through the front door)"
for _ in $(seq 1 30); do curl -fsS "$base/" >/dev/null 2>&1 && break; sleep 1; done
curl -fsS "$base/" | grep -q "<title>Linkly</title>" || fail "page not served at $base/"
body=$(curl -fsS -X POST "$base/api/links" -H 'content-type: application/json' -d '{"url":"https://example.com/k8s"}') || fail "shorten failed"
code=$(echo "$body" | sed -E 's/.*"code":"([^"]+)".*/\1/')
[ ${#code} -eq 7 ] || fail "no code in: $body"
read -r status target < <(curl -s -o /dev/null -w '%{http_code} %{redirect_url}\n' "$base/r/$code" | tr -d '\r')
[ "$status" = "307" ] && [ "$target" = "https://example.com/k8s" ] || fail "redirect gave $status $target"
clicks=0
for _ in $(seq 1 30); do
  clicks=$(curl -fsS "$base/api/links/$code" | sed -E 's/.*"clicks":([0-9]+).*/\1/') || true
  [ "$clicks" -ge 1 ] && break
  sleep 1
done
[ "$clicks" -ge 1 ] || fail "click not counted"

echo "== a killed api pod is replaced and traffic keeps flowing"
victim=$(k get pods -l app=api -o name | head -1)
k delete "$victim" --wait=false >/dev/null
for _ in $(seq 1 10); do [ "$(curl -s -o /dev/null -w '%{http_code}' "$base/r/$code")" = "307" ] || fail "redirect failed while a pod was replaced"; sleep 0.5; done
k rollout status deployment/api --timeout=120s >/dev/null || fail "api not back to full strength"
[ "$(k get deploy api -o jsonpath='{.status.readyReplicas}')" = "2" ] || fail "api replicas not restored"

echo "== data survives the postgres pod being deleted"
k delete pod postgres-0 >/dev/null
k rollout status statefulset/postgres --timeout=180s >/dev/null || fail "postgres not back"
k exec postgres-0 -- psql -U linkly -d linkly -tAc "SELECT count(*) FROM links WHERE code='$code'" | tr -d '\r' | grep -qx 1 || fail "link lost with the postgres pod"
for _ in $(seq 1 30); do [ "$(curl -s -o /dev/null -w '%{http_code}' "$base/r/$code")" = "307" ] && break; sleep 1; done
[ "$(curl -s -o /dev/null -w '%{http_code}' "$base/r/$code")" = "307" ] || fail "link not served after postgres restart"

echo "K8S SMOKE TEST PASSED"
```

- [ ] **Step 1: RED.** Temporarily remove `PGDATA` from `20-postgres.yaml` and run the script. Expected: FAILED at "postgres not ready" (initdb refuses a non-empty directory), or otherwise confirm the volume root contains `lost+found` with kind's local-path provisioner. If it passes anyway, ledger that kind's provisioner has no `lost+found`, keep `PGDATA` as portability for cloud disks, and use a different RED: drop `replicas: 2` to 1 so the "replicas not restored" check fails.
- [ ] **Step 2: GREEN.** Restore the manifests and run it. Expected: `K8S SMOKE TEST PASSED`. Afterwards `kind get clusters` doesn't list `linkly-smoke`.
- [ ] **Step 3: Commit.** Message: `test(linkly): Kubernetes smoke test on a throwaway kind cluster`.

### Task 3: Gateway API front door

**Files:** create `app/linkly/k8s/gateway/gateway.yaml`. It is not applied by `apply -f k8s/` because that isn't recursive.

```yaml
# The Gateway API front door (lesson 7). Needs a Gateway API implementation; we use Envoy Gateway:
#   kubectl apply --server-side -f https://github.com/envoyproxy/gateway/releases/download/v1.9.2/install.yaml
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: eg
spec:
  controllerName: gateway.envoyproxy.io/gatewayclass-controller
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: linkly
  namespace: linkly
spec:
  gatewayClassName: eg
  listeners:
    - name: http
      protocol: HTTP
      port: 80
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: linkly
  namespace: linkly
spec:
  parentRefs:
    - name: linkly
  rules:
    - backendRefs:
        - name: web
          port: 8080
```

- [ ] **Step 1: Verify live** on a kind cluster that has Linkly applied:
  - Install Envoy Gateway v1.9.2 and wait for `deployment/envoy-gateway -n envoy-gateway-system` to be available.
  - Apply `gateway.yaml`.
  - `kubectl wait --for=condition=Programmed gateway/linkly -n linkly`.
  - Find the Envoy Service by label `gateway.envoyproxy.io/owning-gateway-name=linkly`, port-forward it to `localhost:8081`, then shorten and redirect a link through it.
  - Expected: the page is served, the API returns 201, and the redirect returns 307.
  - Ledger the exact commands that worked; lesson 7 uses them.
- [ ] **Step 2: Commit.** Message: `feat(linkly): Gateway API front door (Envoy Gateway)`.

### Task 4: Module 3 lessons

**Files:** `modules/03-kubernetes/README.md` plus eight lessons. Every command is run against a real kind cluster before it goes into a lesson.

**README** ("# Kubernetes Core"):
- **You need:** Module 1 (Docker); Module 2 is useful but not required.
- **Install:** `kind` (`go install sigs.k8s.io/kind@v0.33.0`, or the release binary from GitHub) and `kubectl` (Docker Desktop ships it; on Linux use the official apt repo or a static binary).
- **Before you start:** stop the Compose stack, because it frees 8080.
- **Cost:** free, all local.

**Lesson 1: Why Kubernetes**
- **Concept:** cluster, control plane and nodes, desired state and reconciliation, the API server, kubectl. Compose versus Kubernetes: one machine versus many, with self-healing, scaling and rolling updates.
- **Example:** `kind create cluster --name linkly --config app/linkly/kind-config.yaml`, then `kubectl get nodes` and `kubectl get pods -A`.
- **Lab:** create the cluster; list the system pods and name three of them; find your current context; delete the cluster and recreate it.
- **Check yourself:** what reconciliation means; control plane versus node; which machine `kubectl` talks to.

**Lesson 2: Pods and Deployments**
- **Concept:** pods, labels and selectors, Deployments and ReplicaSets, `kubectl get/describe/logs/exec`.
- **Example:** apply `00-namespace.yaml` and `30-redis.yaml`, run `kubectl -n linkly get pods -o wide`, delete the pod and watch it come back, then scale with `kubectl scale`.
- **Lab:** deploy Redis and find its pod; read the pod's events with `describe`; delete the pod and watch a replacement appear; scale to three replicas and back; explain what the selector connects.
- **Check yourself:** pod versus Deployment; why you rarely create pods directly; what a label selector does.

**Lesson 3: Services and DNS**
- **Concept:** a ClusterIP Service gives a stable name in front of changing pods; DNS names (`redis`, `redis.linkly.svc.cluster.local`); port-forward.
- **Example:** `kubectl -n linkly run tmp --rm -it --image=redis:7-alpine -- redis-cli -h redis ping`, then `kubectl -n linkly port-forward svc/redis 6379:6379`.
- **Lab:** reach Redis by its Service name from a temporary pod; resolve the full DNS name; port-forward a Service to your machine; delete the Redis pod and show the Service still works.
- **Check yourself:** why not use pod IPs; what port-forward is for (debugging, not production).

**Lesson 4: ConfigMaps and Secrets**
- **Concept:** ConfigMap versus Secret, `envFrom` and `secretKeyRef`. Base64 is not encryption, and a later module covers real secret handling.
- **Example:** apply `10-config.yaml`, then `kubectl -n linkly get secret linkly-db -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d`.
- **Lab:** apply the config; read a value back out of the Secret; change `BASE_URL` and see that running pods don't pick it up until they restart (`kubectl rollout restart`); explain why the Secret file shouldn't hold real passwords.
- **Check yourself:** where config should live; what `rollout restart` does.

**Lesson 5: StatefulSets and storage**
- **Concept:** PersistentVolume, PVC, StorageClass (kind's local-path), StatefulSet with stable names and its own volume, the headless Service, and why `PGDATA` points at a subfolder.
- **Example:** apply `20-postgres.yaml`, `kubectl -n linkly get pvc,pv`, create a table, delete `postgres-0`, and show the data is still there.
- **Lab:** run Postgres as a StatefulSet; find its PersistentVolumeClaim; write a row, delete the pod and read the row back; explain what happens to the volume if you delete the StatefulSet.
- **Check yourself:** Deployment versus StatefulSet; what keeps the data; headless Service.

**Lesson 6: All of Linkly on Kubernetes**
- **Concept:** probes (readiness versus liveness), requests and limits, `securityContext`, two API replicas, `kind load docker-image`, and the NodePort front door.
- **Example:**
  - Build the three images with the `:dev` tag and run `kind load`.
  - `kubectl apply -f app/linkly/k8s/`, then the `rollout status` commands.
  - Open http://localhost:8080.
  - Kill an API pod mid-traffic.
  - Run `./k8s-smoke-test.sh`.
- **Lab:** build and load the three images into kind; apply every manifest and wait for the rollouts; use Linkly at localhost:8080; delete an API pod while clicking links; run the Kubernetes smoke test.
- **Check yourself:** readiness versus liveness; what a memory limit does when exceeded (OOMKilled); why `IfNotPresent` matters with kind.

**Lesson 7: The Gateway API**
- **Concept:** why there is a front door in front of Services; Ingress history and the ingress-nginx retirement (March 2026); the Gateway API roles (GatewayClass for infrastructure, Gateway for the cluster operator, HTTPRoute for app teams); implementations (Envoy Gateway, NGINX Gateway Fabric, Istio, Cilium, Traefik).
- **Example:** the exact commands verified in Task 3.
- **Lab:** install Envoy Gateway; apply Linkly's Gateway and HTTPRoute; reach Linkly through the gateway; explain which team owns each of the three resources.
- **Check yourself:** Ingress versus Gateway API; what an HTTPRoute attaches to.

**Lesson 8: Landscape**
- **Concept:** Docker Swarm (simple, built into Docker, in maintenance mode in practice); Nomad (HashiCorp, runs more than containers); managed Kubernetes (EKS in Module 8, plus GKE and AKS); local options (kind, minikube, k3d/k3s, Docker Desktop's Kubernetes); the CNCF.
- **Example:** `docker swarm init` sketch versus our manifests (not run), and `kind get clusters`.
- **Lab:** name two ways to run Kubernetes on your laptop; explain one reason a team might pick Nomad; compare a Swarm stack file with our Compose file.
- **Check yourself:** what "managed Kubernetes" takes off your plate.

- [ ] **Step 1: Verify.**
  - Run the format check on `modules/03-kubernetes`.
  - Run every lesson's commands live, in a kind cluster named `linkly-lessons` mapped to a free host port, and record any deviations in the ledger.
  - Check that the live Course API lists the module (read-only; don't restart JARVIS).
- [ ] **Step 2: Commit.** Message: `docs(module-3): Kubernetes Core - why k8s, pods, services, config, StatefulSets, all of Linkly, Gateway API, landscape`.

### Task 5: Checkpoint for Module 4

- [ ] `git branch checkpoint/04-packaging HEAD`, update the README checkpoint sentence, and commit `docs: checkpoint branch for module 4`.
