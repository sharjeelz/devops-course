#!/usr/bin/env bash
# Records a new image tag on the "deploy" branch, the branch Argo CD deploys from (module 5).
# deploy = main + which image runs: each run merges main into deploy (so chart changes arrive too),
# then sets image.tag in app/linkly/gitops/values.yaml. Its history is the deployment log, and
# reverting a "deploy: ..." commit there is a rollback. Run by CI after a successful build of main;
# safe to run again (nothing new = no commit, no push).
# Usage: app/linkly/gitops/bump-image.sh sha-<7 chars>    (from the repo root, origin = your repo)
set -euo pipefail
tag="${1:?usage: bump-image.sh <image tag, e.g. sha-abc1234>}"
[[ "$tag" =~ ^[A-Za-z0-9._-]+$ ]] || { echo "not a valid image tag: $tag" >&2; exit 2; }
file=app/linkly/gitops/values.yaml
branch="${DEPLOY_BRANCH:-deploy}"   # the branch Argo CD deploys from
main="${MAIN_BRANCH:-main}"         # where the code comes from
bot=(-c user.name="github-actions[bot]" -c user.email="41898282+github-actions[bot]@users.noreply.github.com")

for attempt in 1 2 3; do
  git fetch -q origin "$main"
  if git fetch -q origin "$branch" 2>/dev/null; then
    git switch -q -C "$branch" "origin/$branch"
    # Bring main's changes in. If both sides changed the same lines (values.yaml's tag), keep deploy's.
    git "${bot[@]}" merge -q --no-edit -X ours "origin/$main" -m "deploy: merge $main"
    base="origin/$branch"
  else
    echo "no $branch branch yet: starting it from $main"
    git switch -q -C "$branch" "origin/$main"
    base=""
  fi
  sed -i -E "s/^(  tag: ).*/\1${tag}/" "$file"
  git diff --quiet -- "$file" || git "${bot[@]}" commit -q -m "deploy: linkly $tag" -- "$file"
  if [ -n "$base" ] && [ "$(git rev-parse HEAD)" = "$(git rev-parse "$base")" ]; then
    echo "$branch already deploys $tag with the latest $main"; exit 0
  fi
  if git push -q origin "$branch"; then echo "$branch now deploys $tag"; exit 0; fi
  echo "$branch moved while we were working (attempt $attempt): starting again from the new tip" >&2
done
echo "could not update $branch after 3 attempts" >&2
exit 1
