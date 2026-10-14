#!/usr/bin/env bash
# Tests cleanup.sh with a fake "aws" command that records every call and answers with canned
# resources, so the deletion order can be checked without an AWS account.
# Usage: app/linkly/aws/test-cleanup.sh
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
fails=0
check() { local msg="$1"; shift; if "$@"; then echo "ok - $msg"; else echo "FAIL - $msg"; fails=$((fails + 1)); fi; }

# The fake aws. STATE=full: one of everything exists. STATE=empty: nothing does.
mkdir -p "$tmp/bin"
cat > "$tmp/bin/aws" <<'FAKE'
#!/usr/bin/env bash
echo "$*" >> "$LOG"
full() { [ "$STATE" = full ]; }
case "$1 $2" in
  "ec2 describe-instances")          full && echo "i-0aaa" ;;
  "ec2 describe-key-pairs")          full || exit 254 ;;
  "ec2 describe-vpcs")               full && echo "vpc-0aaa" ;;
  "ec2 describe-security-groups")    full && echo "sg-0aaa" ;;
  "ec2 describe-subnets")            full && echo "subnet-0aaa" ;;
  "ec2 describe-route-tables")       full && echo "rtb-0aaa" ;;
  "ec2 describe-internet-gateways")  full && echo "igw-0aaa" ;;
  "s3api list-buckets")              full && echo "linkly-course-abc123" ;;
  "s3api list-object-versions")
    n=$(cat "$COUNT" 2>/dev/null || echo 0); echo $((n + 1)) > "$COUNT"
    if [ "$n" = 0 ]; then echo '{"Objects": [{"Key": "a.sql.gz", "VersionId": "v1"}]}'; else echo '{"Objects": []}'; fi ;;
  "ecr describe-repositories")       full && printf 'linkly-api\tarn:aws:ecr:eu-central-1:123456789012:repository/linkly-api\n' ;;
  "ecr list-tags-for-resource")      echo "linkly-course" ;;
  "iam get-role")                    full || exit 254 ;;
  "iam list-role-policies")          echo "linkly-course-s3-backup" ;;
  "iam list-attached-role-policies") echo "" ;;
  "iam get-instance-profile")        full || exit 254 ;;
esac
exit 0
FAKE
chmod +x "$tmp/bin/aws"
export PATH="$tmp/bin:$PATH" AWS_REGION=eu-central-1 LOG="$tmp/calls.log" COUNT="$tmp/count"
line() { grep -n -m1 -- "$1" "$LOG" | cut -d: -f1; }
before() { local a b; a=$(line "$1"); b=$(line "$2"); [ -n "$a" ] && [ -n "$b" ] && [ "$a" -lt "$b" ]; }

# 1. Everything exists: everything goes, in an order AWS accepts.
: > "$LOG"; rm -f "$COUNT"
STATE=full "$here/cleanup.sh" > "$tmp/out" 2>&1 || { cat "$tmp/out"; echo "FAIL - cleanup.sh exited non-zero"; exit 1; }
check "terminates the instance before deleting its security group" before "terminate-instances" "delete-security-group"
check "waits for the instance to be gone first" before "wait instance-terminated" "delete-security-group"
check "deletes subnets before the VPC" before "delete-subnet" "delete-vpc"
check "detaches the internet gateway before deleting it" before "detach-internet-gateway" "delete-internet-gateway"
check "deletes the internet gateway before the VPC" before "delete-internet-gateway" "delete-vpc"
check "empties the bucket (all versions) before deleting it" before "delete-objects" "delete-bucket"
check "deletes the course's ECR repository" grep -q "ecr delete-repository --repository-name linkly-api --force" "$LOG"
check "removes the role from its instance profile before deleting the role" before "remove-role-from-instance-profile" "iam delete-role --role-name"
check "deletes the role's inline policy before the role" before "delete-role-policy" "iam delete-role --role-name"
check "deletes the key pair" grep -q "delete-key-pair --key-name linkly-course" "$LOG"

# 2. DRY_RUN lists but never deletes.
: > "$LOG"; rm -f "$COUNT"
STATE=full DRY_RUN=1 "$here/cleanup.sh" > "$tmp/out" 2>&1
check "DRY_RUN makes no delete, terminate, detach or remove calls" bash -c "! grep -Eq ' (delete|terminate|detach|remove)-' '$LOG'"
check "DRY_RUN says what it would delete" grep -q "would delete" "$tmp/out"

# 3. Nothing left: a second run deletes nothing and succeeds.
: > "$LOG"; rm -f "$COUNT"
check "a run with nothing left exits 0" bash -c "STATE=empty '$here/cleanup.sh' >/dev/null 2>&1"
check "and makes no delete calls" bash -c "! grep -Eq ' (delete|terminate|detach|remove)-' '$LOG'"

# 4. AWS_REGION is required (never guess where to delete things).
check "refuses to run without AWS_REGION" bash -c "! env -u AWS_REGION '$here/cleanup.sh' >/dev/null 2>&1"

if [ "$fails" -eq 0 ]; then echo "all cleanup tests passed"; else echo "$fails cleanup test(s) failed"; exit 1; fi
