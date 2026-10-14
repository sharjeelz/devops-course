#!/usr/bin/env bash
# Records a new image tag on the "deploy" branch, the branch Argo CD watches for values (module 5).
# Run by CI after a successful build of main; safe to run again (no change = no commit).
# Usage: app/linkly/gitops/bump-image.sh sha-<7 chars>    (from the repo root, origin = your repo)
set -euo pipefail
tag="${1:?usage: bump-image.sh <image tag, e.g. sha-abc1234>}"
[[ "$tag" =~ ^[A-Za-z0-9._-]+$ ]] || { echo "not a valid image tag: $tag" >&2; exit 2; }
file=app/linkly/gitops/values.yaml
branch="${DEPLOY_BRANCH:-deploy}"   # the branch Argo CD reads values from
author=(-c user.name="github-actions[bot]" -c user.email="41898282+github-actions[bot]@users.noreply.github.com")

if git fetch -q origin "$branch" 2>/dev/null; then
  git switch -q -C "$branch" "origin/$branch"
else
  echo "no $branch branch yet: starting it from the current commit"
  git switch -q -C "$branch"
fi

for attempt in 1 2 3; do
  sed -i -E "s/^(  tag: ).*/\1${tag}/" "$file"
  if git diff --quiet -- "$file"; then echo "$branch already deploys $tag"; exit 0; fi
  git "${author[@]}" commit -q -m "deploy: linkly $tag" -- "$file"
  if git push -q origin "$branch"; then echo "deploy now points at $tag"; exit 0; fi
  echo "$branch moved while we were working (attempt $attempt): starting again from the new tip" >&2
  git fetch -q origin "$branch" && git reset -q --hard "origin/$branch"
done
echo "could not update $branch after 3 attempts" >&2
exit 1
