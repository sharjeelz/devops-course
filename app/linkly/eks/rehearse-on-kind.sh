#!/usr/bin/env bash
# Rehearses Linkly's EKS setup on a throwaway kind cluster (module 8), for free: the same chart
# values, the same add-ons (addons.sh), with stand-ins only where AWS would be:
#   RDS → a Postgres in another namespace (fake-rds.yaml), with a URL-hostile password
#   Secrets Manager → External Secrets' fake provider, serving RDS's JSON shape
#   Let's Encrypt → a self-signed issuer under the same name
# Then it uses Linkly over HTTPS, checks the autoscaler reads CPU, and rotates the password.
# Usage (from the repo root): app/linkly/eks/rehearse-on-kind.sh     (KEEP=1 keeps the cluster)
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
app="$(cd "$here/.." && pwd)"
cluster=linkly-rehearsal
host=linkly.localtest.me
ctx="kind-$cluster"
k() { kubectl --context "$ctx" "$@"; }
fail() { echo "REHEARSAL FAILED: $*" >&2; diagnose; exit 1; }
diagnose() {
  echo "--- diagnostics" >&2
  k get pods -A -o wide >&2 2>&1 || true
  k -n linkly get externalsecret,certificate,gateway,httproute,hpa >&2 2>&1 || true
  k -n linkly describe externalsecret linkly-db 2>&1 | tail -15 >&2 || true
  k -n linkly logs deploy/api --tail=30 >&2 2>&1 || true
}
tmp=$(mktemp -d)
pf_pid=""
cleanup() {
  [ -n "$pf_pid" ] && kill "$pf_pid" 2>/dev/null || true
  rm -rf "$tmp"
  [ "${KEEP:-0}" = 1 ] || kind delete cluster --name "$cluster" >/dev/null 2>&1 || true
}
trap cleanup EXIT
# Wait up to $1 seconds for a command to succeed.
until_ok() { local t=$1; shift; for _ in $(seq 1 "$t"); do "$@" >/dev/null 2>&1 && return 0; sleep 1; done; return 1; }

echo "== kind cluster $cluster"
kind delete cluster --name "$cluster" >/dev/null 2>&1 || true
kind create cluster --name "$cluster" --wait 120s >/dev/null 2>"$tmp/kind.err" || { cat "$tmp/kind.err" >&2; exit 1; }
kubectl config use-context "$ctx" >/dev/null

echo "== images"
for svc in api worker web; do
  docker build -q -t "linkly-${svc}:dev" "$app/$svc" >/dev/null || fail "build $svc"
  kind load docker-image "linkly-${svc}:dev" --name "$cluster" >/dev/null 2>&1 || fail "load $svc"
done

echo "== add-ons (the same script as on EKS)"
KIND=1 "$here/addons.sh" > "$tmp/addons.log" 2>&1 || { tail -20 "$tmp/addons.log" >&2; fail "add-ons"; }

echo "== stand-ins for RDS, Secrets Manager and Let's Encrypt"
k apply -f "$here/rehearsal/fake-rds.yaml" >/dev/null
k apply -f "$here/rehearsal/fake-secrets-manager.yaml" >/dev/null
k -n fake-rds rollout status deploy/postgres --timeout=120s >/dev/null || fail "fake RDS didn't start"

echo "== Linkly, with the EKS values"
helm --kube-context "$ctx" install linkly "$app/helm/linkly" -n linkly --create-namespace \
  -f "$app/helm/linkly/values-eks.yaml" \
  --set image.prefix= --set image.tag=dev \
  --set externalDatabase.host=postgres.fake-rds.svc.cluster.local \
  --set externalDatabase.sslmode=disable \
  --set 'externalDatabase.externalSecret.remoteKey=rds!db-rehearsal' \
  --set externalDatabase.externalSecret.refreshInterval=10s \
  --set gateway.hostname="$host" --set baseUrl="https://$host" >/dev/null || fail "helm install"

echo "== the database credentials came from the secret store, escaped"
until_ok 120 k -n linkly get secret linkly-db || fail "External Secrets didn't create linkly-db"
url=$(k -n linkly get secret linkly-db -o jsonpath='{.data.DATABASE_URL}' | base64 -d)
case "$url" in
  "postgresql://linkly:p%40ss%3Aw%2Frd%231%25%2Bx%3F@postgres.fake-rds.svc.cluster.local:5432/linkly?sslmode=disable") ;;
  *) fail "unexpected DATABASE_URL (password not escaped?)" ;;
esac
for d in api worker web redis; do
  k -n linkly rollout status "deploy/$d" --timeout=240s >/dev/null || fail "$d not ready"
done

echo "== HTTPS through the Gateway, with a certificate from cert-manager"
until_ok 180 bash -c "[ \"\$(kubectl --context $ctx -n linkly get certificate linkly-tls -o jsonpath='{.status.conditions[?(@.type==\"Ready\")].status}')\" = True ]" \
  || fail "the certificate never became ready"
until_ok 120 bash -c "kubectl --context $ctx -n envoy-gateway-system get svc -l gateway.envoyproxy.io/owning-gateway-name=linkly -o name | grep -q ." \
  || fail "Envoy didn't create a service for the Gateway"
svc=$(k -n envoy-gateway-system get svc -l gateway.envoyproxy.io/owning-gateway-name=linkly -o name | head -1)
k -n envoy-gateway-system port-forward "$svc" 18443:443 18080:80 >/dev/null 2>&1 &
pf_pid=$!
base="https://$host:18443"
curl_() { curl -sS --resolve "$host:18443:127.0.0.1" --resolve "$host:18080:127.0.0.1" -k "$@"; }
until_ok 60 curl_ -f "$base/" || fail "Linkly isn't answering over HTTPS"
curl_ -f "$base/" | grep -q "<title>Linkly</title>" || fail "page not served over HTTPS"
issuer=$(curl_ -v -o /dev/null "$base/" 2>&1 | tr -d '\r' | grep -i "issuer:" || true)
[ -n "$issuer" ] || fail "no certificate presented"
read -r status location < <(curl_ -o /dev/null -w '%{http_code} %{redirect_url}\n' "http://$host:18080/" | tr -d '\r')
[ "$status" = 301 ] && [[ "$location" == https://* ]] || fail "plain HTTP should redirect to HTTPS (got $status $location)"
body=$(curl_ -f -X POST "$base/api/links" -H 'content-type: application/json' -d '{"url":"https://example.com/eks"}') \
  || fail "shorten failed (database not reachable?)"
code=$(sed -E 's/.*"code":"([^"]+)".*/\1/' <<<"$body")
[ "$(curl_ -o /dev/null -w '%{http_code}' "$base/r/$code" | tr -d '\r')" = 307 ] || fail "redirect failed"
grep -q "\"short_url\":\"https://$host/r/$code\"" <<<"$body" || fail "short links should use the https base URL: $body"

echo "== the autoscaler reads the api's CPU"
until_ok 180 bash -c "kubectl --context $ctx -n linkly get hpa api -o jsonpath='{.status.currentMetrics[0].resource.current.averageUtilization}' | grep -qE '^[0-9]+$'" \
  || fail "the HPA has no CPU metric (metrics-server?)"
k -n linkly get pdb api >/dev/null || fail "no PodDisruptionBudget"

echo "== RDS rotates the password: the new one reaches the app by itself"
newpw='n3w/p@ss%word'
before=$(k -n linkly get deploy api -o jsonpath='{.metadata.generation}')
k -n fake-rds exec deploy/postgres -- psql -U linkly -d linkly -qc "ALTER USER linkly PASSWORD '$newpw'" >/dev/null \
  || fail "couldn't change the password"
k patch clustersecretstore aws-secrets-manager --type=json -p "[{\"op\":\"replace\",\"path\":\"/spec/provider/fake/data/0/value\",\"value\":\"{\\\"username\\\":\\\"linkly\\\",\\\"password\\\":\\\"$newpw\\\"}\"}]" >/dev/null \
  || fail "couldn't update the fake secret store"
until_ok 120 bash -c "kubectl --context $ctx -n linkly get secret linkly-db -o jsonpath='{.data.DATABASE_URL}' | base64 -d | grep -q 'n3w%2Fp%40ss%25word'" \
  || fail "the rotated password never reached linkly-db"
until_ok 120 bash -c "[ \"\$(kubectl --context $ctx -n linkly get deploy api -o jsonpath='{.metadata.generation}')\" != $before ]" \
  || fail "Reloader didn't restart the api after the rotation"
k -n linkly rollout status deploy/api --timeout=240s >/dev/null || fail "api didn't come back after the rotation"
k -n linkly rollout status deploy/worker --timeout=240s >/dev/null || fail "worker didn't come back after the rotation"
until_ok 60 curl_ -f -X POST "$base/api/links" -H 'content-type: application/json' -d '{"url":"https://example.com/rotated"}' \
  || fail "Linkly can't use the database after the rotation"

echo "REHEARSAL PASSED"
