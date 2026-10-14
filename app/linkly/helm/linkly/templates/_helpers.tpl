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

{{/* Changes whenever the app's config or credentials change, so the api and worker restart on upgrade.
     Postgres doesn't use it: it reads its settings only when it first creates its data. */}}
{{- define "linkly.configChecksum" -}}
{{- print (include (print .Template.BasePath "/config.yaml") .) (include (print .Template.BasePath "/secret.yaml") .) | sha256sum -}}
{{- end }}

{{/* With an external database, the credentials Secret changes when RDS rotates the password: Reloader
     (module 8) then restarts the pods so they pick up the new one. Nothing without one. */}}
{{- define "linkly.reloadAnnotations" -}}
{{- if .Values.externalDatabase.enabled }}
annotations:
  secret.reloader.stakater.com/reload: linkly-db
{{- end }}
{{- end }}
