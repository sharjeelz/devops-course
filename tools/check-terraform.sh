#!/usr/bin/env bash
# Checks Linkly's Terraform without an AWS account (module 7): formatting, validation, and every
# terraform test (they run against a mock AWS provider), plus things tests can't see.
# Usage (from the repo root): tools/check-terraform.sh
set -euo pipefail
cd "$(dirname "$0")/../app/linkly/terraform"
fail() { echo "FAIL: $*" >&2; exit 1; }

echo "== terraform fmt"
terraform fmt -recursive -check || fail "run: terraform fmt -recursive app/linkly/terraform"

for dir in modules/network modules/backups modules/server envs/dev bootstrap; do
  echo "== $dir"
  (
    cd "$dir"
    terraform init -backend=false -input=false -no-color >/dev/null
    terraform validate -no-color >/dev/null
    terraform test -no-color | grep -E '^(Success|Failure)!'
  ) || fail "$dir"
done

echo "== the state bucket can't be destroyed by accident"
grep -q 'prevent_destroy = true' bootstrap/main.tf || fail "bootstrap/main.tf lost prevent_destroy"

echo "== settings terraform test can't see"
grep -q 'ignore_changes = \[ami\]' modules/server/main.tf || fail "a new AL2023 release would replace the server (and its data): keep ignore_changes = [ami]"
grep -q 'use_lockfile = true' envs/dev/backend.tf || fail "envs/dev/backend.tf lost state locking (use_lockfile)"
grep -q 'force_destroy = true' envs/dev/main.tf || fail "envs/dev/main.tf: terraform destroy can't remove a backup bucket with backups in it without force_destroy"

echo "== the start-up script, as Terraform renders it"
rendered=$(mktemp)
trap 'rm -f "$rendered"' EXIT
(
  cd modules/server
  echo 'local.user_data' | terraform console -no-color \
    -var name=t -var vpc_id=v -var subnet_id=s -var allowed_cidr=203.0.113.10/32 -var ssh_public_key=k \
    -var linkly_images=ghcr.io/learner -var linkly_tag=sha-abc1234 -var backup_bucket_arn=arn:aws:s3:::b
) | sed -e '1{/^<<EOT$/d}' -e '${/^EOT$/d}' > "$rendered"
head -1 "$rendered" | grep -q '^#!/bin/bash' || fail "rendered user_data doesn't start with #!/bin/bash"
bash -n "$rendered" || fail "rendered user_data isn't valid bash"
if command -v shellcheck >/dev/null; then
  shellcheck -S warning "$rendered" || fail "shellcheck on rendered user_data"
else
  docker run --rm -i koalaman/shellcheck:stable -S warning - < "$rendered" || fail "shellcheck on rendered user_data"
fi
echo "Terraform checks passed"
