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
