# ECR

> **You need:** Lesson 1 (CLI signed in), Docker on your laptop · **Time:** ~45 min · **Cost:** cents (ECR storage, about $0.10 per GB-month) · **Start from:** `checkpoint/06-aws`

## Why this matters

Your images live on GHCR, which works anywhere. Workloads inside AWS (EKS in Module 8) often
pull from **ECR**, AWS's own registry instead. It's in the same network, its access is controlled
by IAM roles rather than tokens, and it can scan images for known vulnerabilities as they arrive.

## Concept

- **Repositories** hold one image's tags: `linkly-api`, `linkly-worker`, `linkly-web`. The address
  is `<account>.dkr.ecr.<region>.amazonaws.com/linkly-api:<tag>`.
- **Private by default.** `aws ecr get-login-password` gives Docker a 12-hour login token.
- **Scan on push:** each pushed image is checked for known vulnerabilities (CVEs) in its OS packages.
- **Lifecycle policies** expire old images automatically, so storage doesn't grow forever.
- **ECR or GHCR?** GHCR is simpler for open source and for GitHub Actions. ECR fits workloads running
  in AWS that authenticate with IAM roles. Module 8 uses ECR for EKS.

## Example

Copy your published API image from GHCR into ECR:

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGISTRY="$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
aws ecr create-repository --repository-name linkly-api \
  --image-scanning-configuration scanOnPush=true --tags Key=Project,Value=linkly-course
aws ecr get-login-password | docker login --username AWS --password-stdin "$REGISTRY"

docker pull ghcr.io/<you>/linkly-api:sha-<a build>
docker tag ghcr.io/<you>/linkly-api:sha-<a build> "$REGISTRY/linkly-api:sha-<a build>"
docker push "$REGISTRY/linkly-api:sha-<a build>"

aws ecr describe-images --repository-name linkly-api --query 'imageDetails[].[imageTags[0],imageSizeInBytes]'
aws ecr describe-image-scan-findings --repository-name linkly-api --image-id imageTag=sha-<a build> \
  --query 'imageScanFindings.findingSeverityCounts'
aws ecr put-lifecycle-policy --repository-name linkly-api \
  --lifecycle-policy-text file://app/linkly/aws/ecr-lifecycle.json
```

## Lab

- [ ] Create a private ECR repository with scanning on push
- [ ] Push your API image to it
- [ ] Read the vulnerability scan results
- [ ] Add a lifecycle policy that keeps the newest 10 images

## Check yourself

1. Why might a workload in AWS pull from ECR rather than GHCR?

<details><summary>Answer</summary>

Access is granted through IAM roles (no registry token to store and rotate), traffic stays inside
AWS, and it comes with scanning and lifecycle rules out of the box.

</details>

2. What does the lifecycle policy prevent?

<details><summary>Answer</summary>

Every pipeline run adds images; without expiry, storage (and cost) grows forever. The policy
deletes everything but the newest 10.

</details>

## Clean up

Lesson 7's clean-up script force-deletes repositories tagged for the course, images included.
