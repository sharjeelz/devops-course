#!/usr/bin/env bash
# Checks Linkly's Ansible code without any server (module 9): compose.yaml takes the password the
# linkly role writes, then ansible-lint and a syntax check in the lab's control image.
# Usage (from the repo root): tools/check-ansible.sh
set -euo pipefail
cd "$(dirname "$0")/.."
export MSYS_NO_PATHCONV=1   # Git Bash on Windows: don't rewrite /paths given to docker
fails=0
check() { local msg="$1"; shift; if "$@"; then echo "ok - $msg"; else echo "FAIL - $msg"; fails=$((fails + 1)); fi; }
config() { (cd app/linkly && env "$@" docker compose -f compose.yaml config --format json); }

echo "== compose.yaml: the database password"
default=$(config)
custom=$(config LINKLY_DB_PASSWORD=s3cr3tPw)
check "default password is still linkly (Postgres)" grep -q '"POSTGRES_PASSWORD": "linkly"' <<<"$default"
check "default password is still linkly (DATABASE_URL)" grep -q 'postgresql://linkly:linkly@postgres' <<<"$default"
check "LINKLY_DB_PASSWORD sets Postgres' password" grep -q '"POSTGRES_PASSWORD": "s3cr3tPw"' <<<"$custom"
check "LINKLY_DB_PASSWORD reaches the api's DATABASE_URL" grep -q 'postgresql://linkly:s3cr3tPw@postgres' <<<"$custom"
check "and no 'linkly' password is left with it set" bash -c '! grep -q "linkly:linkly@" <<<"$1"' _ "$custom"

if [ "$fails" -eq 0 ]; then echo "all ansible checks passed"; else echo "$fails ansible check(s) failed"; exit 1; fi
