# Writing a chart

> **You need:** Lesson 3 (Linkly installed with Helm) · **Time:** ~75 min · **Start from:** `checkpoint/04-packaging`

## Why this matters

Using a chart is half the story. Your own apps need their own charts, and debugging anyone's
chart means reading templates. Linkly's chart is small enough to read in one sitting and uses
the techniques you'll meet everywhere.

## Concept

Open `app/linkly/helm/linkly/`:

- **`Chart.yaml`:** the chart's name, its own `version` (bump it when the chart changes) and
  the `appVersion` it deploys.
- **`values.yaml`:** every setting with a sensible default and a comment. Defaults target a
  local kind cluster.
- **`templates/`:** Kubernetes YAML with Go template placeholders:
  - `{{ .Values.api.replicas }}` inserts a value; `{{ .Release.Name }}` and `{{ .Chart.Version }}` come from Helm.
  - `{{- toYaml .Values.api.resources | nindent 12 }}` turns a block of values into YAML,
    indented to fit. Most template bugs are indentation bugs.
  - `{{- if eq .Values.web.service.type "NodePort" }} … {{- end }}` only adds `nodePort` when it applies.
- **`templates/_helpers.tpl`:** reusable snippets, `define`d once and `include`d everywhere.
  Linkly's has the standard labels, the image name (which uses `required`, so a missing tag fails
  loudly), and a config checksum.
- **The checksum annotation:** the api and worker pods carry `checksum/config: <hash of the
  ConfigMap and Secret>`. When a setting changes in an upgrade, the hash changes, the pod template
  changes, and Kubernetes rolls those pods. That's the automatic version of Module 3's
  `rollout restart`. Postgres deliberately has *no* checksum: restarting the database for a
  `BASE_URL` change would only drop writes.
- **Passwords are different.** Postgres reads `POSTGRES_PASSWORD` only when it first creates its
  data. Changing `postgres.password` in a later upgrade would update the Secret but *not* the
  database's real password, so the api and worker would fail to log in (and clicks would quietly
  stop being counted). Changing a database password needs `ALTER USER` inside Postgres; Module 8
  does it properly. If you try it here, `helm rollback` fixes it.
- **Checked inputs:** `templates/secret.yaml` checks the user, database and password contain only
  letters, digits and `_`, because they go into `DATABASE_URL`, and converts them to text first,
  because `--set` turns an all-digit password into a number.
- **Selectors stay `app: <name>`.** Selectors can't be changed after a Deployment exists, and
  nginx, the smoke test and Module 3 all rely on them, so the chart *adds* labels but never changes these.
- **`templates/NOTES.txt`:** what's printed after install.

## Example

```bash
cd app/linkly
helm template linkly helm/linkly | less                  # render everything, install nothing
helm template linkly helm/linkly --set api.replicas=4 --show-only templates/api.yaml | grep replicas   # replicas: 4
helm lint helm/linkly                                     # 0 chart(s) failed
```

Watch the checksum work:

```bash
kubectl -n linkly get pods -l app=api
helm upgrade linkly helm/linkly -n linkly --set baseUrl=http://localhost:9999
kubectl -n linkly rollout status deploy/api
kubectl -n linkly get pods -l app=api                     # new pod names: they were replaced
kubectl -n linkly exec deploy/api -c api -- printenv BASE_URL   # http://localhost:9999
```

Put it back with `helm upgrade linkly helm/linkly -n linkly` (no `--set`: back to the defaults).

## Lab

- [ ] Render the chart without installing it
- [ ] Break a template on purpose and read Helm's error
- [ ] Render the chart with a different API replica count
- [ ] Show that a config change in an upgrade replaces the pods by itself

Hint for breaking it: change `nindent 12` to `nindent 6` in `templates/api.yaml` and run
`helm template`. The error points at the YAML line it couldn't parse. Then undo it.

## Check yourself

1. What does `nindent` do, and why does it matter so much?

<details><summary>Answer</summary>

It adds a newline and indents the inserted text by N spaces. YAML structure is indentation, so
the wrong number produces invalid YAML or, worse, valid YAML in the wrong place.

</details>

2. Why don't the selectors use the chart's nice `app.kubernetes.io/*` labels?

<details><summary>Answer</summary>

A Deployment's selector is immutable, and other parts (nginx, the smoke test, Module 3's
manifests) select on `app: <name>`. Adding labels is safe; changing selectors would break
upgrades and everything that relies on them.

</details>

3. Why does Linkly's chart need the checksum annotation?

<details><summary>Answer</summary>

Pods read config only when they start. Without the annotation, `helm upgrade` would change the
ConfigMap or Secret and leave running pods on the old values. The hash changes the pod template,
so Kubernetes rolls them.

</details>
