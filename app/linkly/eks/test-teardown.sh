#!/usr/bin/env bash
# Tests teardown.sh with fake kubectl, terraform and aws commands that record every call, so the
# order (load balancers gone before terraform destroy) is checked without a cluster or an account.
# Usage: app/linkly/eks/test-teardown.sh
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
fails=0
check() { local msg="$1"; shift; if "$@"; then echo "ok - $msg"; else echo "FAIL - $msg"; fails=$((fails + 1)); fi; }

mkdir -p "$tmp/bin"
# kubectl: the cluster answers; LoadBalancer Services disappear after $LB_POLLS polls ("never": stay).
cat > "$tmp/bin/kubectl" <<'FAKE'
#!/usr/bin/env bash
echo "kubectl $*" >> "$LOG"
case "$*" in
  *cluster-info*) [ "$CLUSTER" = up ] || exit 1 ;;
  *"get svc"*)
    n=$(cat "$POLLS" 2>/dev/null || echo 0); echo $((n + 1)) > "$POLLS"
    if [ "$LB_POLLS" = never ] || [ "$n" -lt "$LB_POLLS" ]; then echo "envoy-gateway-system/envoy-linkly LoadBalancer"; fi ;;
esac
exit 0
FAKE
cat > "$tmp/bin/terraform" <<'FAKE'
#!/usr/bin/env bash
echo "terraform $*" >> "$LOG"
exit 0
FAKE
# aws: after destroy, $LEFTOVER says whether a Kubernetes-made load balancer is still there.
cat > "$tmp/bin/aws" <<'FAKE'
#!/usr/bin/env bash
echo "aws $*" >> "$LOG"
case "$*" in
  *get-resources*) [ "$LEFTOVER" = yes ] && echo "arn:aws:elasticloadbalancing:eu-central-1:123456789012:loadbalancer/a1b2c3" ;;
esac
exit 0
FAKE
chmod +x "$tmp/bin/"*
export PATH="$tmp/bin:$PATH" AWS_REGION=eu-central-1 LOG="$tmp/calls.log" POLLS="$tmp/polls" TEARDOWN_WAIT=5
line() { grep -n -m1 -- "$1" "$LOG" | cut -d: -f1; }
before() { local a b; a=$(line "$1"); b=$(line "$2"); [ -n "$a" ] && [ -n "$b" ] && [ "$a" -lt "$b" ]; }
run_it() { : > "$LOG"; rm -f "$POLLS"; env "$@" "$here/teardown.sh" > "$tmp/out" 2>&1; }

# 1. Normal: the app goes, the load balancer goes, then Terraform destroys, then nothing is left.
run_it CLUSTER=up LB_POLLS=2 LEFTOVER=no || { cat "$tmp/out"; echo "FAIL - teardown exited non-zero"; fails=$((fails + 1)); }
check "deletes Linkly's Argo CD Application first" before "delete application linkly" "terraform"
check "waits for the LoadBalancer Services before destroying" before "get svc" "terraform"
check "runs terraform destroy" grep -q "^terraform destroy" "$LOG"
check "checks for leftover load balancers afterwards" before "terraform destroy" "get-resources"

# 2. A load balancer that never goes away: don't destroy (the VPC would fail, the LB keeps billing).
run_it CLUSTER=up LB_POLLS=never LEFTOVER=no && { echo "FAIL - should have stopped"; fails=$((fails + 1)); }
check "never destroys while a LoadBalancer Service remains" bash -c "! grep -q '^terraform destroy' '$LOG'"
check "says which Service is in the way" grep -q "envoy-linkly" "$tmp/out"

# 3. A load balancer left in AWS after destroy: say so, and fail.
run_it CLUSTER=up LB_POLLS=0 LEFTOVER=yes && { echo "FAIL - should report the leftover"; fails=$((fails + 1)); }
check "reports a leftover load balancer" grep -q "loadbalancer/a1b2c3" "$tmp/out"

# 4. The cluster is already gone: still destroy, and still check for leftovers.
run_it CLUSTER=down LB_POLLS=never LEFTOVER=no || { cat "$tmp/out"; echo "FAIL - should continue without a cluster"; fails=$((fails + 1)); }
check "without a cluster, goes straight to destroy" grep -q "^terraform destroy" "$LOG"

# 5. Deleting the Application must take its resources with it.
check "application-eks.yaml has Argo CD's resources finalizer" \
  grep -q "resources-finalizer.argocd.argoproj.io" "$here/../gitops/application-eks.yaml"

check "refuses to run without AWS_REGION" bash -c "! env -u AWS_REGION '$here/teardown.sh' >/dev/null 2>&1"

if [ "$fails" -eq 0 ]; then echo "all teardown tests passed"; else echo "$fails teardown test(s) failed"; exit 1; fi
