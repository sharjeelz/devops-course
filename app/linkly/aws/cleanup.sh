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

echo "== EC2 instances in $AWS_REGION"
mapfile -t instances < <(aws ec2 describe-instances --filters "$tag" \
  "Name=instance-state-name,Values=pending,running,stopping,stopped" \
  --query 'Reservations[].Instances[].InstanceId' --output text | words)
if [ "${#instances[@]}" -gt 0 ]; then
  run ec2 terminate-instances --instance-ids "${instances[@]}"
  [ "$dry" = 1 ] || { echo "  waiting for them to terminate..."; aws ec2 wait instance-terminated --instance-ids "${instances[@]}"; }
fi

echo "== Key pair"
if aws ec2 describe-key-pairs --key-names linkly-course >/dev/null 2>&1; then
  run ec2 delete-key-pair --key-name linkly-course
fi

echo "== VPCs and their network parts"
for vpc in $(aws ec2 describe-vpcs --filters "$tag" --query 'Vpcs[].VpcId' --output text | words); do
  for sg in $(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$vpc" \
      --query "SecurityGroups[?GroupName!='default'].GroupId" --output text | words); do
    run ec2 delete-security-group --group-id "$sg"
  done
  for subnet in $(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc" --query 'Subnets[].SubnetId' --output text | words); do
    run ec2 delete-subnet --subnet-id "$subnet"
  done
  for rtb in $(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$vpc" \
      --query 'RouteTables[?!(Associations[?Main])].RouteTableId' --output text | words); do
    run ec2 delete-route-table --route-table-id "$rtb"
  done
  for igw in $(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$vpc" \
      --query 'InternetGateways[].InternetGatewayId' --output text | words); do
    run ec2 detach-internet-gateway --internet-gateway-id "$igw" --vpc-id "$vpc"
    run ec2 delete-internet-gateway --internet-gateway-id "$igw"
  done
  run ec2 delete-vpc --vpc-id "$vpc"
done

echo "== S3 buckets (linkly-course-*)"
for bucket in $(aws s3api list-buckets --query "Buckets[?starts_with(Name, 'linkly-course-')].Name" --output text | words); do
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
while IFS=$'\t' read -r name arn; do
  [ -n "${name:-}" ] && [ "$name" != None ] || continue
  owner=$(aws ecr list-tags-for-resource --resource-arn "$arn" --query "tags[?Key=='Project'].Value" --output text | words)
  [ "$owner" = linkly-course ] && run ecr delete-repository --repository-name "$name" --force
done < <(aws ecr describe-repositories --query 'repositories[].[repositoryName,repositoryArn]' --output text)

echo "== IAM role and instance profile (linkly-course-ec2)"
if aws iam get-instance-profile --instance-profile-name linkly-course-ec2 >/dev/null 2>&1; then
  if aws iam get-role --role-name linkly-course-ec2 >/dev/null 2>&1; then
    run iam remove-role-from-instance-profile --instance-profile-name linkly-course-ec2 --role-name linkly-course-ec2
  fi
  run iam delete-instance-profile --instance-profile-name linkly-course-ec2
fi
if aws iam get-role --role-name linkly-course-ec2 >/dev/null 2>&1; then
  for p in $(aws iam list-role-policies --role-name linkly-course-ec2 --query 'PolicyNames' --output text | words); do
    run iam delete-role-policy --role-name linkly-course-ec2 --policy-name "$p"
  done
  for arn in $(aws iam list-attached-role-policies --role-name linkly-course-ec2 --query 'AttachedPolicies[].PolicyArn' --output text | words); do
    run iam detach-role-policy --role-name linkly-course-ec2 --policy-arn "$arn"
  done
  run iam delete-role --role-name linkly-course-ec2
fi

if [ "$dry" = 1 ]; then echo "Dry run: nothing was deleted."
else echo "Done. Check with: aws resourcegroupstaggingapi get-resources --tag-filters Key=Project,Values=linkly-course"; fi
