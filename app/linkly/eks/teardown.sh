#!/usr/bin/env bash
# Tears down Module 8's EKS environment in an order that works (module 8). Kubernetes, not
# Terraform, created the load balancer in front of Linkly's Gateway, so Terraform can't remove it,
# and while it exists the VPC can't be deleted (and it keeps billing). So:
#   1. delete Linkly's Argo CD Application (its finalizer removes the Gateway and its Service),
#   2. wait until no LoadBalancer Service is left, so the load balancer is gone,
#   3. terraform destroy (it asks you to confirm),
#   4. check that AWS has no load balancer left that Kubernetes made for this cluster.
# Usage (from the repo root): AWS_REGION=eu-central-1 app/linkly/eks/teardown.sh
set -euo pipefail
: "${AWS_REGION:?set AWS_REGION to the region you used, e.g. AWS_REGION=eu-central-1}"
export AWS_PAGER=""
cd "$(dirname "$0")/../terraform/envs/eks"
wait_s="${TEARDOWN_WAIT:-300}"
cluster=linkly-course

load_balancer_services() {
  kubectl get svc -A -o jsonpath='{range .items[?(@.spec.type=="LoadBalancer")]}{.metadata.namespace}/{.metadata.name} {.spec.type}{"\n"}{end}'
}

if kubectl cluster-info >/dev/null 2>&1; then
  echo "== removing Linkly (and with it the Gateway's load balancer)"
  kubectl -n argocd delete application linkly --ignore-not-found --wait=true --timeout="${wait_s}s"
  kubectl -n linkly delete gateway --all --ignore-not-found    # in case it was installed without Argo CD

  echo "== waiting for every LoadBalancer Service to go (up to ${wait_s}s)"
  left=""
  for _ in $(seq 1 "$wait_s"); do
    left=$(load_balancer_services)
    [ -z "$left" ] && break
    sleep 1
  done
  if [ -n "$left" ]; then
    echo "These Services still have load balancers, so terraform destroy would fail:" >&2
    echo "$left" >&2
    echo "Delete them (kubectl -n <namespace> delete svc <name>) and run this again." >&2
    exit 1
  fi
else
  echo "== can't reach the cluster (already gone?): skipping straight to terraform destroy"
fi

echo "== terraform destroy"
terraform destroy

echo "== anything Kubernetes made that's still in AWS?"
leftovers=$(aws resourcegroupstaggingapi get-resources --region "$AWS_REGION" \
  --tag-filters "Key=kubernetes.io/cluster/$cluster" \
  --query 'ResourceTagMappingList[].ResourceARN' --output text | tr '\t' '\n' | grep -v -e '^$' -e '^None$' || true)
if [ -n "$leftovers" ]; then
  echo "Still there (and possibly billing): delete these in the EC2 console (Load Balancers, Security Groups):" >&2
  echo "$leftovers" >&2
  exit 1
fi
echo "Done: the EKS environment is gone. (Module 7's state bucket stays, on purpose.)"
