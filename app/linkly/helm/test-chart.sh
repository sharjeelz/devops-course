#!/usr/bin/env bash
# Checks what Linkly's chart renders for each way of using it (modules 4 and 8), with helm template
# only: no cluster needed. Usage (from the repo root): app/linkly/helm/test-chart.sh
set -euo pipefail
chart="$(cd "$(dirname "$0")" && pwd)/linkly"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
fails=0
check() { local msg="$1"; shift; if "$@"; then echo "ok - $msg"; else echo "FAIL - $msg"; fails=$((fails + 1)); fi; }

render() { helm template t "$chart" "$@" > "$tmp/out.yaml"; }
# doc KIND NAME: print one rendered object (empty if it isn't there).
doc() {
  awk -v kind="$1" -v name="$2" '
    /^---/ { if (k == kind && n == name) printf "%s", buf; buf = ""; k = ""; n = ""; inmeta = 0; next }
    { buf = buf $0 "\n" }
    /^kind: / { k = $2 }
    /^metadata:/ { inmeta = 1; next }
    inmeta && /^  name: / && n == "" { n = $2 }
    /^[a-z]/ && !/^metadata:/ { inmeta = 0 }
    END { if (k == kind && n == name) printf "%s", buf }
  ' "$tmp/out.yaml"
}
has() { [ -n "$(doc "$1" "$2")" ]; }
lacks() { [ -z "$(doc "$1" "$2")" ]; }
in_doc() { doc "$1" "$2" | grep -qE -- "$3"; }
fails_with() { local want="$1"; shift; ! helm template t "$chart" "$@" > /dev/null 2> "$tmp/err" && grep -q -- "$want" "$tmp/err"; }

eks=(--set image.tag=sha-test --set externalDatabase.enabled=true --set externalDatabase.host=linkly.abc.eu-central-1.rds.amazonaws.com
  --set externalDatabase.externalSecret.secretStore=aws-secrets --set externalDatabase.externalSecret.remoteKey=rds!db-123)

# 1. Defaults: exactly the in-cluster setup from module 4.
render
check "default: in-cluster postgres" has StatefulSet postgres
check "default: the linkly-db Secret" has Secret linkly-db
check "default: no ExternalSecret" lacks ExternalSecret linkly-db
check "default: api has a fixed replica count" in_doc Deployment api "^  replicas: 2( |$)"
check "default: no HPA" lacks HorizontalPodAutoscaler api
check "default: the init container waits on DATABASE_URL" in_doc Deployment api 'pg_isready -d .{0,2}[$]DATABASE_URL'

# 2. External database (RDS): no postgres in the cluster, the Secret comes from External Secrets.
render "${eks[@]}"
check "external: no postgres StatefulSet" lacks StatefulSet postgres
check "external: no postgres Service" lacks Service postgres
check "external: the chart doesn't create linkly-db itself" lacks Secret linkly-db
check "external: an ExternalSecret named linkly-db" has ExternalSecret linkly-db
check "external: reads the RDS secret" in_doc ExternalSecret linkly-db 'key: "?rds!db-123'
check "external: from the given store" in_doc ExternalSecret linkly-db "name: aws-secrets"
check "external: escapes the username and password into the URL" in_doc ExternalSecret linkly-db '\.username \| urlquery.*\.password \| urlquery'
check "external: points at the RDS host with TLS required" in_doc ExternalSecret linkly-db '@linkly\.abc\.eu-central-1\.rds\.amazonaws\.com:5432/linkly\?sslmode=require'
check "external: no postgres password needed" render "${eks[@]}" --set postgres.password=
check "external: a host is required" fails_with "externalDatabase.host is required" "${eks[@]}" --set externalDatabase.host=

# 3. Autoscaling: the HPA owns the replica count, and a PDB keeps some pods during node drains.
render --set image.tag=t --set api.autoscaling.enabled=true
check "hpa: an HPA for the api" has HorizontalPodAutoscaler api
check "hpa: between min and max" in_doc HorizontalPodAutoscaler api "minReplicas: 2"
check "hpa: scales on CPU" in_doc HorizontalPodAutoscaler api "averageUtilization: 70"
check "hpa: the Deployment leaves replicas to the HPA" bash -c "! grep -q '^  replicas:' <<<\"\$1\"" _ "$(doc Deployment api)"
check "pdb: at most one api pod down at a time" in_doc PodDisruptionBudget api "maxUnavailable: 1"

# 4. HTTPS on the Gateway, with a certificate from cert-manager.
render --set image.tag=t --set gateway.enabled=true --set gateway.tls.enabled=true \
  --set gateway.hostname=linkly.example.com --set gateway.tls.clusterIssuer=letsencrypt
check "tls: cert-manager is asked for a certificate" in_doc Gateway linkly "cert-manager.io/cluster-issuer: letsencrypt"
check "tls: an HTTPS listener on 443" in_doc Gateway linkly "port: 443"
check "tls: using the linkly-tls Secret" in_doc Gateway linkly "name: linkly-tls"
check "tls: for the hostname" in_doc Gateway linkly "hostname: linkly.example.com"
check "tls: the app's route is on HTTPS" in_doc HTTPRoute linkly "sectionName: https"
check "tls: plain HTTP redirects to HTTPS" in_doc HTTPRoute linkly-redirect "scheme: https"
check "tls: a hostname is required" fails_with "gateway.hostname is required" --set image.tag=t --set gateway.enabled=true --set gateway.tls.enabled=true
render --set image.tag=t --set gateway.enabled=true
check "no tls: the Gateway is plain HTTP as before" bash -c "! grep -q 'port: 443' <<<\"\$1\"" _ "$(doc Gateway linkly)"
check "no tls: no redirect route" lacks HTTPRoute linkly-redirect

if [ "$fails" -eq 0 ]; then echo "all chart tests passed"; else echo "$fails chart test(s) failed"; exit 1; fi
