{{- define "mural.labels" -}}
app.kubernetes.io/name: mural
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "mural.migrations" -}}
{{ (.Files.Glob "files/migrations/*.sql").AsConfig }}
{{- end -}}

{{- define "mural.migrationHash" -}}
{{- printf "%s:%s:%s" (include "mural.migrations" .) .Values.postgres.image (toJson .Values.migration.resources) | sha256sum | trunc 10 -}}
{{- end -}}
