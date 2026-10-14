#!/usr/bin/env bash
# Rehearses Module 9 end to end in the local lab: configures the bastion and web1 with site.yml,
# checks that Linkly works on web1, runs the playbook again and requires that nothing changed,
# then checks SSH hardening, the bastion path, the vaulted password and a reboot.
# Usage (from the repo root): app/linkly/ansible/lab/rehearse.sh     (KEEP=1 keeps the lab running)
set -euo pipefail
here="$(cd "$(dirname "$0")" && { pwd -W 2>/dev/null || pwd; })"   # pwd -W: a C:/ path for docker on Windows
export MSYS_NO_PATHCONV=1   # Git Bash on Windows: don't rewrite /paths given to docker
export LAB_WEB_PORT="${LAB_WEB_PORT:-18081}"
base="http://localhost:${LAB_WEB_PORT}"
lab() { docker compose -f "$here/compose.yaml" "$@"; }
# Run a command on the control node, with the rehearsal's own copy of the lab inventory (so a
# vault.yml you made in lesson 4 is left alone, and isn't needed).
c() { lab exec -T -e ANSIBLE_INVENTORY=/tmp/lab-inventory/hosts.yml control "$@"; }
fails=0
check() { local msg="$1"; shift; if "$@"; then echo "ok - $msg"; else echo "FAIL - $msg"; fails=$((fails + 1)); fi; }
fail() { echo "REHEARSAL FAILED: $*" >&2; exit 1; }
tmp=$(mktemp -d)
cleanup() {
  rm -rf "$tmp"
  [ "${KEEP:-0}" = 1 ] || lab down -v --remove-orphans >/dev/null 2>&1 || true
}
trap cleanup EXIT
until_ok() { local t=$1; shift; for _ in $(seq 1 "$t"); do "$@" >/dev/null 2>&1 && return 0; sleep 1; done; return 1; }

echo "== the lab: control, bastion, web1"
lab down -v --remove-orphans >/dev/null 2>&1 || true
lab up -d --build --quiet-pull >"$tmp/up.log" 2>&1 || { tail -20 "$tmp/up.log" >&2; fail "lab didn't start"; }

echo "== an SSH key for the lab, and a vaulted database password"
c bash -c 'rm -rf /tmp/lab-inventory && cp -r inventories/lab /tmp/lab-inventory && rm -f /tmp/lab-inventory/group_vars/linkly/vault.yml'
c bash -c 'test -f /keys/id_ed25519 || ssh-keygen -q -t ed25519 -N "" -C ansible-lab -f /keys/id_ed25519
           cp /keys/id_ed25519.pub /keys/authorized_keys && chmod 0644 /keys/authorized_keys'
# What a person does with `ansible-vault create`, done by a script: a random password for Postgres,
# encrypted with a vault password that exists only in this lab's keys volume.
password=$(c python -c 'import secrets; print(secrets.token_hex(16))' | tr -d '\r')
c bash -c 'python -c "import secrets; print(secrets.token_urlsafe(24))" > /keys/vault-pass && chmod 0600 /keys/vault-pass'
printf 'vault_linkly_db_password: %s\n' "$password" | c bash -c \
  'ansible-vault encrypt --vault-password-file /keys/vault-pass --output /tmp/lab-inventory/group_vars/linkly/vault.yml -'
check "the vault file is encrypted" bash -c "docker compose -f '$here/compose.yaml' exec -T control head -1 /tmp/lab-inventory/group_vars/linkly/vault.yml | grep -q '^\\\$ANSIBLE_VAULT'"
play() { c ansible-playbook site.yml --vault-password-file /keys/vault-pass "$@"; }

echo "== waiting for both hosts to answer over SSH"
pingall() { c ansible all -m ansible.builtin.ping --vault-password-file /keys/vault-pass; }
until_ok 90 pingall || { pingall >&2 || true; fail "hosts not reachable"; }

echo "== site.yml, first run"
play > "$tmp/run1.log" 2>&1 || { tail -40 "$tmp/run1.log" >&2; fail "first run failed"; }
check "the first run changed things" grep -Eq 'web1 +: ok=[0-9]+ +changed=[1-9]' "$tmp/run1.log"
check "the database password never appears in Ansible's output" bash -c "! grep -q '$password' '$tmp/run1.log'"

echo "== Linkly on web1"
check "the page is served" bash -c "curl -fsS '$base/' | grep -q '<title>Linkly</title>'"
code=$(curl -fsS -X POST "$base/api/links" -H 'content-type: application/json' \
  -d '{"url":"https://example.com/ansible"}' | sed -n 's/.*"code": *"\([^"]*\)".*/\1/p')
check "a link can be shortened" test -n "$code"
check "and it redirects" bash -c "curl -s -o /dev/null -w '%{redirect_url}' '$base/r/$code' | grep -q 'example.com/ansible'"
check "the api uses the vaulted password" bash -c "docker compose -f '$here/compose.yaml' exec -T web1 docker exec linkly-api-1 printenv DATABASE_URL | grep -q 'linkly:$password@postgres'"
check ".env is readable by root only" bash -c "[ \"\$(docker compose -f '$here/compose.yaml' exec -T web1 stat -c '%a %U' /opt/linkly/.env | tr -d '\r')\" = '600 root' ]"

echo "== site.yml, second run: nothing should change"
# Fresh SSH connections (Ansible keeps them open for a minute), so this run goes through the
# bastion as it is now configured, not through a connection made before.
c bash -c 'rm -rf ~/.ansible/cp'
play > "$tmp/run2.log" 2>&1 || { tail -40 "$tmp/run2.log" >&2; fail "second run failed"; }
check "idempotent: changed=0 on every host" bash -c "grep -E '^(bastion|web1) +: ' '$tmp/run2.log' | grep -Ev 'changed=0 ' | { ! grep -q .; }"
grep -E '^(bastion|web1) +: ' "$tmp/run2.log" | grep -Ev 'changed=0 ' >&2 || true

echo "== drift: a change by hand is found by --check and undone by the next run"
play --check > "$tmp/check-clean.log" 2>&1 || { tail -30 "$tmp/check-clean.log" >&2; fail "check mode failed"; }
check "check mode on configured hosts: no drift" bash -c "grep -E '^(bastion|web1) +: ' '$tmp/check-clean.log' | grep -Ev 'changed=0 ' | { ! grep -q .; }"
lab exec -T web1 rm /etc/ssh/sshd_config.d/10-hardening.conf
play --check > "$tmp/check-drift.log" 2>&1 || true
check "check mode finds the deleted hardening file" grep -Eq 'web1 +: ok=[0-9]+ +changed=[1-9]' "$tmp/check-drift.log"
check "and changes nothing itself" bash -c "! docker compose -f '$here/compose.yaml' exec -T web1 test -f /etc/ssh/sshd_config.d/10-hardening.conf"
play > "$tmp/run3.log" 2>&1 || { tail -30 "$tmp/run3.log" >&2; fail "third run failed"; }
check "the next run puts it back" bash -c "docker compose -f '$here/compose.yaml' exec -T web1 test -f /etc/ssh/sshd_config.d/10-hardening.conf"

echo "== SSH hardening"
# What the server offers a client without a key: only "publickey" (no "password" or "keyboard-interactive").
c ssh -o BatchMode=yes -o PubkeyAuthentication=no ec2-user@bastion true 2>"$tmp/denied" || true
check "the bastion offers key logins only" grep -q 'Permission denied (publickey)' "$tmp/denied"
sshd_t() { lab exec -T "$1" sshd -T 2>/dev/null | tr -d '\r'; }
check "no password logins on web1" grep -qx 'passwordauthentication no' <(sshd_t web1)
check "no root logins on web1" grep -qx 'permitrootlogin no' <(sshd_t web1)
check "web1 forwards no TCP" grep -qx 'allowtcpforwarding no' <(sshd_t web1)
sshd_t bastion > "$tmp/sshd-bastion"
check "the bastion forwards TCP" grep -qx "allowtcpforwarding yes" "$tmp/sshd-bastion"
check "but only to SSH ports" grep -Fqx "permitopen *:22" "$tmp/sshd-bastion"
check "web1 runs no X11 forwarding" grep -qx 'x11forwarding no' <(sshd_t web1)

echo "== the bastion path"
check "web1 isn't reachable directly from the control node" bash -c "! docker compose -f '$here/compose.yaml' exec -T control ssh -o BatchMode=yes -o ConnectTimeout=5 ec2-user@web1 true 2>/dev/null"
check "alice reaches web1 through the bastion and may sudo" \
  c ssh -o BatchMode=yes -J ec2-user@bastion alice@web1 sudo -n true
# ssh -W: ask the bastion for a plain TCP connection onward. To web1's SSH port it must work...
check "the bastion forwards to web1's SSH port" bash -c \
  "docker compose -f '$here/compose.yaml' exec -T control timeout 10 ssh -o BatchMode=yes -W web1:22 ec2-user@bastion </dev/null 2>/dev/null | head -c 7 | grep -q 'SSH-2.0'"
# ...but not to Linkly's port: the bastion is a door for SSH, not a tunnel to everything inside.
printf 'GET / HTTP/1.0\r\n\r\n' | c timeout 10 ssh -o BatchMode=yes -W web1:8080 ec2-user@bastion >"$tmp/tunnel" 2>/dev/null || true
check "the bastion refuses to forward to other ports" bash -c "! grep -q 'HTTP/1' '$tmp/tunnel'"

echo "== a reboot: Linkly comes back by itself"
lab restart web1 >/dev/null
check "Linkly is back after web1 restarts" until_ok 240 bash -c "curl -fsS '$base/' | grep -q '<title>Linkly</title>'"
check "and the link survived" bash -c "curl -s -o /dev/null -w '%{redirect_url}' '$base/r/$code' | grep -q 'example.com/ansible'"

if [ "$fails" -eq 0 ]; then echo "REHEARSAL PASSED"; else echo "REHEARSAL: $fails check(s) failed"; exit 1; fi
