#!/usr/bin/env bash
# Deletes everything Module 6 created in one region: resources tagged Project=linkly-course, buckets
# named linkly-course-*, the key pair and IAM role linkly-course(-ec2). In an order AWS accepts, and
# safe to run again (things already gone are skipped).
#   AWS_REGION=eu-central-1 DRY_RUN=1 app/linkly/aws/cleanup.sh    # show what would be deleted
#   AWS_REGION=eu-central-1 app/linkly/aws/cleanup.sh              # delete it
set -euo pipefail
: "${AWS_REGION:?set AWS_REGION to the region you used, e.g. AWS_REGION=eu-central-1}"
export AWS_REGION AWS_PAGER=""
dry="${DRY_RUN:-0}"
tag="Name=tag:Project,Values=linkly-course"

# run: delete something (or, with DRY_RUN=1, only say so).
run() {
  if [ "$dry" = 1 ]; then echo "  would delete: aws $*"; return; fi
  echo "  aws $*"
  aws "$@" >/dev/null
}
# words: the non-empty, non-"None" words of a text answer.
words() { tr '\t' '\n' | grep -v -e '^$' -e '^None$' || true; }
# list: ask AWS for IDs, and stop the whole script if it can't answer: an expired session must never
# look like "nothing left". Always as an assignment (ids=$(list ...)), so a failure stops the script.
list() {
  local out
  out=$(aws "$@" --output text) || { echo "FAILED: aws $* (nothing after this point was deleted)" >&2; exit 1; }
  words <<<"$out"
}
# exists: 0 if it exists, 1 if AWS says it doesn't; any other error (access denied...) stops the script.
exists() {
  local err
  if err=$(aws "$@" 2>&1 >/dev/null); then return 0; fi
  case "$err" in *NotFound*|*NoSuchEntity*) return 1 ;; esac
  echo "FAILED: aws $*: $err" >&2
  exit 1
}

aws sts get-caller-identity >/dev/null 2>&1 || {
  echo "Not signed in to AWS (or the session expired). Run: aws sso login --profile linkly (or: aws login --profile linkly)" >&2
  exit 1
}

echo "== EC2 instances in $AWS_REGION"
# shutting-down too: an instance terminated by hand holds on to its security group for a while.
ids=$(list ec2 describe-instances --filters "$tag" \
  "Name=instance-state-name,Values=pending,running,shutting-down,stopping,stopped" \
  --query 'Reservations[].Instances[].InstanceId')
mapfile -t instances < <(words <<<"$ids")
if [ "${#instances[@]}" -gt 0 ]; then
  run ec2 terminate-instances --instance-ids "${instances[@]}"
  [ "$dry" = 1 ] || { echo "  waiting for them to terminate..."; aws ec2 wait instance-terminated --instance-ids "${instances[@]}"; }
fi

echo "== Key pair"
if exists ec2 describe-key-pairs --key-names linkly-course; then
  run ec2 delete-key-pair --key-name linkly-course
fi

echo "== VPCs and their network parts"
vpcs=$(list ec2 describe-vpcs --filters "$tag" --query 'Vpcs[].VpcId')
for vpc in $vpcs; do
  sgs=$(list ec2 describe-security-groups --filters "Name=vpc-id,Values=$vpc" \
    --query "SecurityGroups[?GroupName!='default'].GroupId")
  for sg in $sgs; do
    run ec2 delete-security-group --group-id "$sg"
  done
  subnets=$(list ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc" --query 'Subnets[].SubnetId')
  for subnet in $subnets; do
    run ec2 delete-subnet --subnet-id "$subnet"
  done
  rtbs=$(list ec2 describe-route-tables --filters "Name=vpc-id,Values=$vpc" \
    --query 'RouteTables[?!(Associations[?Main])].RouteTableId')
  for rtb in $rtbs; do
    run ec2 delete-route-table --route-table-id "$rtb"
  done
  igws=$(list ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$vpc" \
    --query 'InternetGateways[].InternetGatewayId')
  for igw in $igws; do
    run ec2 detach-internet-gateway --internet-gateway-id "$igw" --vpc-id "$vpc"
    run ec2 delete-internet-gateway --internet-gateway-id "$igw"
  done
  run ec2 delete-vpc --vpc-id "$vpc"
done

echo "== S3 buckets (linkly-course-*)"
buckets=$(list s3api list-buckets --query "Buckets[?starts_with(Name, 'linkly-course-')].Name")
for bucket in $buckets; do
  if [ "$dry" = 1 ]; then echo "  would delete: bucket $bucket and every object version in it"; continue; fi
  # A versioned bucket keeps old versions and delete markers: remove them all, a page at a time.
  while :; do
    batch=$(aws s3api list-object-versions --bucket "$bucket" --max-items 1000 \
      --query '{Objects: [Versions[], DeleteMarkers[]][].{Key: Key, VersionId: VersionId}}' --output json)
    case "$batch" in *'"Key"'*) run s3api delete-objects --bucket "$bucket" --delete "$batch" ;; *) break ;; esac
  done
  run s3api delete-bucket --bucket "$bucket"
done

echo "== ECR repositories tagged for the course"
repos=$(aws ecr describe-repositories --query 'repositories[].[repositoryName,repositoryArn]' --output text) ||
  { echo "FAILED: aws ecr describe-repositories (nothing after this point was deleted)" >&2; exit 1; }
while IFS=$'\t' read -r name arn; do
  [ -n "${name:-}" ] && [ "$name" != None ] || continue
  owner=$(list ecr list-tags-for-resource --resource-arn "$arn" --query "tags[?Key=='Project'].Value")
  if [ "$owner" = linkly-course ]; then run ecr delete-repository --repository-name "$name" --force; fi
done <<<"$repos"

echo "== IAM role and instance profile (linkly-course-ec2)"
if exists iam get-instance-profile --instance-profile-name linkly-course-ec2; then
  if exists iam get-role --role-name linkly-course-ec2; then
    run iam remove-role-from-instance-profile --instance-profile-name linkly-course-ec2 --role-name linkly-course-ec2
  fi
  run iam delete-instance-profile --instance-profile-name linkly-course-ec2
fi
if exists iam get-role --role-name linkly-course-ec2; then
  policies=$(list iam list-role-policies --role-name linkly-course-ec2 --query 'PolicyNames')
  for p in $policies; do
    run iam delete-role-policy --role-name linkly-course-ec2 --policy-name "$p"
  done
  attached=$(list iam list-attached-role-policies --role-name linkly-course-ec2 --query 'AttachedPolicies[].PolicyArn')
  for arn in $attached; do
    run iam detach-role-policy --role-name linkly-course-ec2 --policy-arn "$arn"
  done
  run iam delete-role --role-name linkly-course-ec2
fi

if [ "$dry" = 1 ]; then echo "Dry run: nothing was deleted."
else echo "Done. Check with: aws resourcegroupstaggingapi get-resources --tag-filters Key=Project,Values=linkly-course"; fi
