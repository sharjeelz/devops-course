#!/usr/bin/env bash
# Builds and starts Linkly with Docker Compose, uses it through nginx like a person would,
# restarts it to prove the data survives, then removes everything it created.
# Usage: ./smoke-test.sh   It uses its own port (18080) and project name, so it doesn't clash with
# a Linkly you already have running; LINKLY_PORT=19090 ./smoke-test.sh if 18080 is taken.
set -euo pipefail
cd "$(dirname "$0")"
export LINKLY_PORT="${LINKLY_PORT:-18080}"
export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-linkly-smoke}"
base="http://localhost:${LINKLY_PORT}"

fail() { echo "SMOKE TEST FAILED: $*" >&2; docker compose logs --tail 30 >&2 || true; exit 1; }
cleanup() { docker compose down -v --remove-orphans >/dev/null 2>&1 || true; }
trap cleanup EXIT

echo "== build and start"
docker compose up -d --build --wait || fail "stack did not become healthy"

echo "== images don't run as root"
for svc in api worker; do
  uid=$(docker compose exec -T "$svc" id -u) || fail "$svc: can't run id"
  [ "$uid" != "0" ] || fail "$svc runs as root"
done

echo "== the page is served"
curl -fsS "$base/" | grep -q "<title>Linkly</title>" || fail "page not served at $base/"

echo "== shorten, redirect, count"
body=$(curl -fsS -X POST "$base/api/links" -H 'content-type: application/json' -d '{"url":"https://example.com/smoke"}') || fail "shorten failed"
code=$(echo "$body" | sed -E 's/.*"code":"([^"]+)".*/\1/')
[ ${#code} -eq 7 ] || fail "no code in: $body"
# tr: curl on Windows (Git Bash) ends -w output with \r\n
read -r status target < <(curl -s -o /dev/null -w '%{http_code} %{redirect_url}\n' "$base/r/$code" | tr -d '\r')
[ "$status" = "307" ] && [ "$target" = "https://example.com/smoke" ] || fail "redirect gave $status $target"
curl -s -o /dev/null "$base/r/$code"
clicks=0
for _ in $(seq 1 20); do
  clicks=$(curl -fsS "$base/api/links/$code" | sed -E 's/.*"clicks":([0-9]+).*/\1/')
  [ "$clicks" -ge 2 ] && break
  sleep 1
done
[ "$clicks" -eq 2 ] || fail "expected 2 clicks, got $clicks"

echo "== bad input is refused"
[ "$(curl -s -o /dev/null -w '%{http_code}' -X POST "$base/api/links" -H 'content-type: application/json' -d '{"url":"javascript:alert(1)"}')" = "422" ] || fail "javascript: URL not refused"

echo "== data survives a restart (down without -v)"
docker compose down >/dev/null 2>&1 || fail "down failed"
docker compose up -d --wait >/dev/null 2>&1 || fail "restart failed"
[ "$(curl -s -o /dev/null -w '%{http_code}' "$base/r/$code")" = "307" ] || fail "link lost after restart"

echo "== the worker stops cleanly when asked (SIGTERM, not killed)"
start=$(date +%s)
docker compose stop worker >/dev/null 2>&1 || fail "stopping the worker failed"
took=$(( $(date +%s) - start ))
exit_code=$(docker inspect -f '{{.State.ExitCode}}' "$(docker compose ps -aq worker)")
[ "$exit_code" = "0" ] && [ "$took" -le 6 ] || fail "worker took ${took}s to stop and exited with $exit_code (137 = killed)"

echo "SMOKE TEST PASSED"
