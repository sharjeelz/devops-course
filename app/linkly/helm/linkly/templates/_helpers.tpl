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
