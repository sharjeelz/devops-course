# Module 4 (Packaging: Helm and Kustomize) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Linkly gets a Helm chart (with values per environment) and Kustomize overlays, so one set of manifests serves a local kind cluster and a production-like setup that pulls GHCR images and uses the Gateway API. CI proves both by deploying to a throwaway kind cluster on every push. Seven lessons teach the two tools, writing a chart, environments, and upgrades and rollbacks.

**Architecture:**
- **Helm chart** in `app/linkly/helm/linkly/`. Service and Deployment names stay fixed (`api`, `web`, `postgres`, `redis`, `worker`), because nginx's config and the smoke test depend on them, so the chart installs one Linkly per namespace.
- **Image names** are `<image.prefix>linkly-<svc>:<image.tag>`.
- **Pods restart on config changes:** a checksum annotation rolls the pods when config or credentials change in an upgrade.
- **Kustomize base** is `app/linkly/k8s/` via a file named `Kustomization`. Kustomize accepts that name, and `kubectl apply -f k8s/` from Module 3 keeps ignoring it because it has no `.yaml` extension.
- **Kustomize overlays** live in `app/linkly/kustomize/{dev,prod}`.
- **Smoke test:** `k8s-smoke-test.sh` gains `DEPLOY=plain|kustomize|helm`.
- **CI:** gains a `kubernetes` job with a matrix over `[helm, kustomize]`, and `publish` now waits for it.

**Tech Stack:** Helm v4.3.0, Kustomize (built into kubectl 1.36), kind v0.33.0, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-10-14-course-design.md`, module map row 4: "Helm chart for Linkly, values per environment".

## Global Constraints

- **Lesson format:** same as before. Every lesson header names "Start from: `checkpoint/04-packaging`". The module README brings the module's files in from `checkpoint/05-gitops`, as Modules 1 and 3 do.
- **Chart and manifests must match.** The chart renders the same objects as `app/linkly/k8s/` with default values (same names, labels used by selectors, probes, securityContext, initContainer, preStop), plus standard `app.kubernetes.io/*` labels. The selectors stay `app: <name>`.
- **No real secrets.** No real credentials go in values files. `postgres.password` defaults to a local-only value; `values-prod.yaml` says to pass it with `--set` or an external secret (Module 8).
- **No `latest` tags.** The prod values require an explicit `image.tag`, and rendering fails with a clear message if it's missing.
- **No outside chart repositories.** Lessons don't depend on third-party chart repositories (public catalogs have changed terms before); everything uses Linkly's own chart.
- **Commits** end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **Installing the prod values without `image.tag`.** It must fail at render time with a helpful message, not deploy `linkly-api:`. Pinned in Task 1 (`helm template` with prod values and no tag returns an error naming `image.tag`).
2. **A config or credential change in a `helm upgrade`.** The pods must pick it up, unlike Module 3's manual restart. Pinned in Task 1 (checksum annotation; verified live in Task 4).
3. **Prod overlay or values switching the web Service to ClusterIP.** No `nodePort` may be left behind, which would be invalid. Pinned in Tasks 1 and 2 (render check: no `nodePort` with ClusterIP).
4. **`helm rollback` after a bad upgrade** (e.g. a nonexistent image tag). The rollback must restore service without dropping requests. Pinned in Task 4 (live, lesson 6).
5. **CI runners lacking kind or helm.** The job installs pinned versions itself. Pinned in Task 3 (first real run).

---

### Task 1: The Helm chart

Create these files under `app/linkly/helm/linkly/`:

`Chart.yaml`:

```yaml
apiVersion: v2
name: linkly
description: Linkly, the course's URL shortener - web, api, worker, Postgres and Redis.
type: application
version: 0.1.0          # the chart's own version: bump when the chart changes
appVersion: "0.2.0"     # the Linkly version these templates were written for
```

`values.yaml`:

```yaml
# Linkly's Helm chart (module 4). The defaults suit a local kind cluster with images loaded as :dev.
# One Linkly per namespace: the Services keep fixed names (api, web, postgres, redis), as nginx expects.

image:
  prefix: ""                    # "" = local images (kind load); e.g. "ghcr.io/<you>/" for GHCR
  tag: dev
  pullPolicy: IfNotPresent

baseUrl: http://localhost:8080  # used to build short links

postgres:
  image: postgres:16-alpine
  user: linkly
  password: linkly              # local only. Letters and digits: it goes into DATABASE_URL.
  database: linkly
  storage: 1Gi
  resources:
    requests: { cpu: 50m, memory: 128Mi }
    limits: { memory: 512Mi }

redis:
  image: redis:7-alpine
  resources:
    requests: { cpu: 25m, memory: 32Mi }
    limits: { memory: 128Mi }

api:
  replicas: 2
  resources:
    requests: { cpu: 50m, memory: 96Mi }
    limits: { memory: 256Mi }

worker:
  replicas: 1
  resources:
    requests: { cpu: 25m, memory: 64Mi }
    limits: { memory: 192Mi }

web:
  replicas: 1
  service:
    type: NodePort              # NodePort for kind (see kind-config.yaml); ClusterIP behind a Gateway
    nodePort: 30080
  resources:
    requests: { cpu: 25m, memory: 32Mi }
    limits: { memory: 128Mi }

gateway:
  enabled: false                # true: a Gateway + HTTPRoute (needs a Gateway API implementation installed)
  className: eg
```

`values-prod.yaml`:

```yaml
# A production-like setup: images from GHCR, three API replicas, traffic through the Gateway API.
#   helm install linkly app/linkly/helm/linkly -n linkly --create-namespace \
#     -f app/linkly/helm/linkly/values-prod.yaml --set image.tag=sha-<commit> --set postgres.password=<secret>
# Change the prefix to your own GHCR namespace.
image:
  prefix: ghcr.io/sharjeelz/
  tag: ""                       # required: pin an exact build (sha-<commit> or a release like 0.2.0)

api:
  replicas: 3

web:
  service:
    type: ClusterIP

gateway:
  enabled: true
```

`templates/_helpers.tpl`:

```yaml
{{/* Labels every Linkly object carries (the selectors keep using the short "app" label). */}}
{{- define "linkly.labels" -}}
app.kubernetes.io/name: linkly
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
{{- end }}

{{/* A Linkly image: (list $ "linkly-api") → <prefix>linkly-api:<tag>. The tag is required. */}}
{{- define "linkly.image" -}}
{{- $root := index . 0 -}}
{{- $name := index . 1 -}}
{{- printf "%s%s:%s" $root.Values.image.prefix $name (required "image.tag is required: pin an exact image, e.g. --set image.tag=sha-abc1234" $root.Values.image.tag) -}}
{{- end }}

{{/* Changes whenever config or credentials change, so pods restart on upgrade. */}}
{{- define "linkly.configChecksum" -}}
{{- include (print .Template.BasePath "/config.yaml") . | sha256sum -}}
{{- end }}
```

`templates/config.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: linkly-config
  labels:
    {{- include "linkly.labels" . | nindent 4 }}
data:
  REDIS_URL: redis://redis:6379/0
  BASE_URL: {{ .Values.baseUrl | quote }}
---
# base64, not encryption: never put a real password in values files (Module 8).
apiVersion: v1
kind: Secret
metadata:
  name: linkly-db
  labels:
    {{- include "linkly.labels" . | nindent 4 }}
type: Opaque
stringData:
  POSTGRES_USER: {{ .Values.postgres.user | quote }}
  POSTGRES_PASSWORD: {{ required "postgres.password is required" .Values.postgres.password | quote }}
  POSTGRES_DB: {{ .Values.postgres.database | quote }}
  DATABASE_URL: {{ printf "postgresql://%s:%s@postgres:5432/%s" .Values.postgres.user .Values.postgres.password .Values.postgres.database | quote }}
```

`templates/postgres.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: postgres
  labels:
    {{- include "linkly.labels" . | nindent 4 }}
spec:
  clusterIP: None
  selector:
    app: postgres
  ports:
    - port: 5432
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
  labels:
    {{- include "linkly.labels" . | nindent 4 }}
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
        {{- include "linkly.labels" . | nindent 8 }}
      annotations:
        checksum/config: {{ include "linkly.configChecksum" . }}
    spec:
      containers:
        - name: postgres
          image: {{ .Values.postgres.image }}
          envFrom:
            - secretRef:
                name: linkly-db
          env:
            - name: PGDATA
              value: /var/lib/postgresql/data/pgdata
          ports:
            - containerPort: 5432
          readinessProbe:
            exec:
              command: ["pg_isready", "-h", "127.0.0.1", "-U", {{ .Values.postgres.user | quote }}, "-d", {{ .Values.postgres.database | quote }}]
            periodSeconds: 3
          resources:
            {{- toYaml .Values.postgres.resources | nindent 12 }}
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
            storage: {{ .Values.postgres.storage }}
```

`templates/redis.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: redis
  labels:
    {{- include "linkly.labels" . | nindent 4 }}
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
  labels:
    {{- include "linkly.labels" . | nindent 4 }}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
        {{- include "linkly.labels" . | nindent 8 }}
    spec:
      containers:
        - name: redis
          image: {{ .Values.redis.image }}
          ports:
            - containerPort: 6379
          readinessProbe:
            exec:
              command: ["redis-cli", "ping"]
            periodSeconds: 3
          resources:
            {{- toYaml .Values.redis.resources | nindent 12 }}
```

`templates/api.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: api
  labels:
    {{- include "linkly.labels" . | nindent 4 }}
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
  labels:
    {{- include "linkly.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.api.replicas }}
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
        {{- include "linkly.labels" . | nindent 8 }}
      annotations:
        checksum/config: {{ include "linkly.configChecksum" . }}
    spec:
      securityContext:
        runAsNonRoot: true
      initContainers:
        - name: wait-for-postgres
          image: {{ .Values.postgres.image }}
          command: ["sh", "-c", "until pg_isready -h postgres -U {{ .Values.postgres.user }} -d {{ .Values.postgres.database }}; do echo waiting for postgres; sleep 2; done"]
          securityContext:
            runAsUser: 70
            allowPrivilegeEscalation: false
      containers:
        - name: api
          image: {{ include "linkly.image" (list $ "linkly-api") }}
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          envFrom:
            - configMapRef:
                name: linkly-config
          env:
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef: { name: linkly-db, key: DATABASE_URL }
          ports:
            - containerPort: 8000
          readinessProbe:
            httpGet: { path: /healthz, port: 8000 }
            periodSeconds: 3
          livenessProbe:
            httpGet: { path: /healthz, port: 8000 }
            initialDelaySeconds: 10
            periodSeconds: 10
          lifecycle:
            preStop:
              sleep: { seconds: 5 }
          resources:
            {{- toYaml .Values.api.resources | nindent 12 }}
          securityContext:
            allowPrivilegeEscalation: false
```

`templates/worker.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: worker
  labels:
    {{- include "linkly.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.worker.replicas }}
  selector:
    matchLabels:
      app: worker
  template:
    metadata:
      labels:
        app: worker
        {{- include "linkly.labels" . | nindent 8 }}
      annotations:
        checksum/config: {{ include "linkly.configChecksum" . }}
    spec:
      securityContext:
        runAsNonRoot: true
      terminationGracePeriodSeconds: 15
      containers:
        - name: worker
          image: {{ include "linkly.image" (list $ "linkly-worker") }}
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          envFrom:
            - configMapRef:
                name: linkly-config
          env:
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef: { name: linkly-db, key: DATABASE_URL }
          resources:
            {{- toYaml .Values.worker.resources | nindent 12 }}
          securityContext:
            allowPrivilegeEscalation: false
```

`templates/web.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web
  labels:
    {{- include "linkly.labels" . | nindent 4 }}
spec:
  type: {{ .Values.web.service.type }}
  selector:
    app: web
  ports:
    - port: 8080
      targetPort: 8080
      {{- if eq .Values.web.service.type "NodePort" }}
      nodePort: {{ .Values.web.service.nodePort }}
      {{- end }}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  labels:
    {{- include "linkly.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.web.replicas }}
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
        {{- include "linkly.labels" . | nindent 8 }}
    spec:
      securityContext:
        runAsNonRoot: true
      containers:
        - name: web
          image: {{ include "linkly.image" (list $ "linkly-web") }}
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - containerPort: 8080
          readinessProbe:
            httpGet: { path: /, port: 8080 }
            periodSeconds: 3
          resources:
            {{- toYaml .Values.web.resources | nindent 12 }}
          securityContext:
            allowPrivilegeEscalation: false
```

`templates/gateway.yaml`:

```yaml
{{- if .Values.gateway.enabled }}
# The front door through the Gateway API. The GatewayClass is cluster infrastructure, so it isn't
# part of this chart: install a Gateway API implementation first (module 3, lesson 7).
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: linkly
  labels:
    {{- include "linkly.labels" . | nindent 4 }}
spec:
  gatewayClassName: {{ .Values.gateway.className }}
  listeners:
    - name: http
      protocol: HTTP
      port: 80
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: linkly
  labels:
    {{- include "linkly.labels" . | nindent 4 }}
spec:
  parentRefs:
    - name: linkly
  rules:
    - backendRefs:
        - name: web
          port: 8080
{{- end }}
```

`templates/NOTES.txt`:

```
Linkly {{ .Chart.AppVersion }} is installed in namespace {{ .Release.Namespace }} (images: {{ .Values.image.prefix }}linkly-*:{{ .Values.image.tag }}).

Wait for it:   kubectl -n {{ .Release.Namespace }} rollout status deploy/api
{{- if eq .Values.web.service.type "NodePort" }}
Open it:       http://localhost:8080   (kind maps node port {{ .Values.web.service.nodePort }} there)
{{- else if .Values.gateway.enabled }}
Reach it:      through the Gateway "linkly" (on kind: port-forward the Envoy Service, module 3 lesson 7)
{{- else }}
Reach it:      kubectl -n {{ .Release.Namespace }} port-forward svc/web 8080:8080
{{- end }}
```

- [ ] **Step 1: Verify.** Each check and its expected result:
  - `helm lint app/linkly/helm/linkly` and `helm lint app/linkly/helm/linkly -f app/linkly/helm/linkly/values-prod.yaml --set image.tag=sha-test`: 0 failures.
  - `helm template t app/linkly/helm/linkly -f app/linkly/helm/linkly/values-prod.yaml`: fails with "image.tag is required".
  - `helm template t app/linkly/helm/linkly -f app/linkly/helm/linkly/values-prod.yaml --set image.tag=sha-test | grep -c nodePort`: 0.
  - A default render against `kubectl apply -f k8s/`: same object kinds and names (compare `kind/name` lists).
  - On a kind cluster, `helm template ... | kubectl apply --dry-run=server -f -`: all objects are valid.
- [ ] **Step 2: Commit.** Message: `feat(linkly): Helm chart with dev defaults and production-like values`.

### Task 2: Kustomize base and overlays

`app/linkly/k8s/Kustomization`:

```yaml
# Makes this folder a Kustomize base (module 4). The file has no .yaml extension on purpose:
# kubectl apply -f k8s/ (module 3) only reads .yaml/.yml/.json files, so it skips this one.
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - 00-namespace.yaml
  - 10-config.yaml
  - 20-postgres.yaml
  - 30-redis.yaml
  - 40-api.yaml
  - 50-worker.yaml
  - 60-web.yaml
```

`app/linkly/kustomize/dev/kustomization.yaml`:

```yaml
# Local kind cluster: the base as it is, labelled as the dev environment.
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../k8s
labels:
  - pairs:
      environment: dev
```

`app/linkly/kustomize/prod/kustomization.yaml`:

```yaml
# Production-like: GHCR images pinned to one build, three API replicas, no NodePort.
# Change newName to your own GHCR namespace and newTag to the build you want.
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../k8s
labels:
  - pairs:
      environment: prod
images:
  - name: linkly-api
    newName: ghcr.io/sharjeelz/linkly-api
    newTag: sha-85779b4
  - name: linkly-worker
    newName: ghcr.io/sharjeelz/linkly-worker
    newTag: sha-85779b4
  - name: linkly-web
    newName: ghcr.io/sharjeelz/linkly-web
    newTag: sha-85779b4
replicas:
  - name: api
    count: 3
patches:
  - target:
      kind: Service
      name: web
    patch: |-
      - op: replace
        path: /spec/type
        value: ClusterIP
      - op: remove
        path: /spec/ports/0/nodePort
```

- [ ] **Step 1: Verify.** Each check and its expected result:
  - `kubectl kustomize app/linkly/kustomize/prod`: images are `ghcr.io/sharjeelz/linkly-*:sha-85779b4`, api has `replicas: 3`, the web Service is `ClusterIP` with no `nodePort`, and every object has `environment: prod`.
  - `kubectl apply -f app/linkly/k8s/ --dry-run=server` still works (the `Kustomization` file is skipped).
  - `kubectl apply -k app/linkly/kustomize/dev --dry-run=server` succeeds.
- [ ] **Step 2: Commit.** Message: `feat(linkly): Kustomize base and dev/prod overlays`.

### Task 3: Smoke test modes and CI

- [ ] **Step 1: RED.** Add `DEPLOY` to `k8s-smoke-test.sh`, replacing the single `kubectl apply -f k8s/` line:

```bash
case "${DEPLOY:-plain}" in
  plain)     kubectl --context "kind-${cluster}" apply -f k8s/ >/dev/null || fail "apply" ;;
  kustomize) kubectl --context "kind-${cluster}" apply -k kustomize/dev >/dev/null || fail "apply -k" ;;
  helm)      helm --kube-context "kind-${cluster}" install linkly helm/linkly -n linkly --create-namespace >/dev/null || fail "helm install" ;;
  *)         fail "DEPLOY must be plain, kustomize or helm" ;;
esac
```

Also update the usage comment. Run `DEPLOY=helm ./k8s-smoke-test.sh` before the chart exists (or with the chart moved aside). Expected: `FAILED: helm install`.
- [ ] **Step 2: GREEN.** Run `DEPLOY=helm`, `DEPLOY=kustomize` and `DEPLOY=plain` (each with its own `CLUSTER` name). All three should print `K8S SMOKE TEST PASSED`.
- [ ] **Step 3: CI job.** In `.github/workflows/ci.yml`, add the job below and change `publish`'s `needs: smoke` to `needs: [smoke, kubernetes]`:

```yaml
  kubernetes:
    needs: [lint, test]
    runs-on: ubuntu-24.04
    strategy:
      fail-fast: false
      matrix:
        deploy: [helm, kustomize]
    steps:
      - uses: actions/checkout@v7
      - name: Install kind and Helm (pinned)
        run: |
          curl -fsSLo kind https://kind.sigs.k8s.io/dl/v0.33.0/kind-linux-amd64
          sudo install -m 0755 kind /usr/local/bin/kind && rm kind
          curl -fsSL https://get.helm.sh/helm-v4.3.0-linux-amd64.tar.gz | tar xz linux-amd64/helm
          sudo install -m 0755 linux-amd64/helm /usr/local/bin/helm && rm -r linux-amd64
          kind version && helm version --short && kubectl version --client
      - name: Deploy Linkly to a throwaway kind cluster and use it
        run: app/linkly/k8s-smoke-test.sh
        env:
          DEPLOY: ${{ matrix.deploy }}
```

  actionlint must give 0 findings. After the branch is merged and pushed (with the user's go-ahead), the first real run must pass both matrix legs; ledger the result.
- [ ] **Step 4: Commit.** Message: `test(linkly): smoke test deploys with plain manifests, Kustomize or Helm; CI deploys to kind`.

### Task 4: Module 4 lessons

Put `modules/04-packaging/README.md` and the seven lessons below in `modules/04-packaging/`. Run every lesson command live on a kind cluster named `linkly-lessons` (host port 18095) and ledger any deviation. Each lesson needs real Example commands, Lab items and Check-yourself answers.

**README.**
- **You need:** Module 3.
- **Install:** Helm v4.3.0 (download from the Helm releases page, or use a package manager). Kustomize is built into kubectl.
- **Before you start:** bring the module files in from `checkpoint/05-gitops` (upstream fallback); free port 8080.
- **Cost:** free, all local.

**Lesson 1, `01-why-packaging`.**
- **Concept:** the copy-paste problem when one app runs in several environments; templating (Helm) versus patching (Kustomize).
- **Example:** `diff` between the dev and prod renders.
- **Lab:** list what differs between dev and prod for Linkly · render both and compare · decide which differences belong in values or patches.
- **Check yourself:** Helm versus Kustomize in one sentence each.

**Lesson 2, `02-kustomize`.**
- **Concept:** base and overlays; `resources`, `images`, `replicas`, `patches`, `labels`; `kubectl kustomize` and `kubectl apply -k`; why the base file is named `Kustomization`.
- **Example:** render prod, apply dev on kind, run `kubectl diff -k`.
- **Lab:** render the prod overlay and find its three changes · apply the dev overlay · add a patch that changes the worker's memory limit · preview the change with `kubectl diff -k`.
- **Check yourself:** base versus overlay; why a JSON patch was needed for `nodePort`.

**Lesson 3, `03-helm-basics`.**
- **Concept:** chart, release, revision, values; `helm install`/`list`/`status`/`get values`/`get manifest`/`uninstall`; releases stored as Secrets in the namespace; Helm 4.
- **Example:** install Linkly's chart on kind.
- **Lab:** install Linkly with Helm · list releases and read the release's status and notes · see the values and manifest Helm used · uninstall and reinstall.
- **Check yourself:** chart versus release; where Helm keeps release history.

**Lesson 4, `04-writing-a-chart`.**
- **Concept:** a walk through `Chart.yaml`, `values.yaml`, the templates, `_helpers.tpl`, `required`, `toYaml`/`nindent`, `NOTES.txt`; `helm template` and `helm lint`; the checksum annotation.
- **Example:** add a value (e.g. `worker.replicas`), render it, lint it.
- **Lab:** render the chart without installing it · break a template on purpose and read the error · make the worker's replica count configurable and render it · show that a config change restarts pods through the checksum.
- **Check yourself:** what `nindent` is for; why selectors stay `app: <name>`.

**Lesson 5, `05-environments`.**
- **Concept:** values files per environment; `--set`; pinning images by `sha-` tag from Module 2's pipeline; the required `image.tag` failing on purpose; prod values on kind with Envoy Gateway and port-forward; the Kustomize prod overlay for comparison.
- **Example:** install with `values-prod.yaml --set image.tag=sha-<your build>` on a cluster with Envoy Gateway installed.
- **Lab:** try the prod values without a tag and read the error · install the prod values with your own GHCR images · reach Linkly through the Gateway · compare the Helm prod render with the Kustomize prod overlay.
- **Check yourself:** why the tag is required; which values differ per environment.

**Lesson 6, `06-upgrades-and-rollbacks`.**
- **Concept:** `helm upgrade`, revision history, `helm rollback`, `--atomic`/`--wait`, upgrading with zero failed requests (thanks to Module 3's preStop), and a bad upgrade (nonexistent tag) leaving pods in ImagePullBackOff while old pods keep serving.
- **Example:** run a load loop through an upgrade that changes `api.replicas` and `baseUrl`, then a broken upgrade, then a rollback.
- **Lab:** upgrade Linkly while requests keep flowing · read the release history · make a bad upgrade on purpose and see what keeps serving · roll back and confirm the fix.
- **Check yourself:** why a bad image tag doesn't take the site down; what `--atomic` does.

**Lesson 7, `07-landscape`.**
- **Concept:**
  - Helm's history: v2 with Tiller, then v3, then v4.
  - Charts as OCI artifacts (`helm push` to GHCR).
  - Public chart catalogs, and why to check their images' terms.
  - Alternatives: Kustomize, plus cdk8s, Jsonnet/Tanka, Timoni and Carvel's ytt.
  - When to use each.
- **Example:** `helm package app/linkly/helm/linkly`, plus a `helm push` sketch (not run).
- **Lab:** package the chart · explain when you'd pick Kustomize over Helm · name one tool that generates manifests from code.
- **Check yourself:** what an OCI chart is.

- [ ] **Step 1: Verify.** The format check on `modules/04-packaging` passes; the live command run is ledgered; the Course API lists the module (read-only).
- [ ] **Step 2: Commit.** Message: `docs(module-4): Packaging - why, Kustomize, Helm basics, writing a chart, environments, upgrades and rollbacks, landscape`.

### Task 5: Checkpoint for Module 5

- [ ] Create `checkpoint/05-gitops` at HEAD and update the README checkpoint sentence. Commit: `docs: checkpoint branch for module 5`.
