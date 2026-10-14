#!/usr/bin/env bash
# Records a new image tag on the "deploy" branch, the branch Argo CD deploys from (module 5).
# deploy = main + which image runs: each run merges the commit CI built (SOURCE_REF, default: the tip
# of main) into deploy, so chart changes arrive with their image, then sets image.tag in
# app/linkly/gitops/values.yaml. Where main and deploy disagree, main wins (the tag is set afterwards
# anyway). deploy's history is the deployment log; reverting a "deploy: linkly ..." commit there is a
# rollback. Safe to run again: nothing new = no commit, no push.
# Usage: app/linkly/gitops/bump-image.sh sha-<7 chars>    (from the repo root, origin = your repo)
#        CI: SOURCE_REF=$GITHUB_SHA app/linkly/gitops/bump-image.sh "sha-${GITHUB_SHA::7}"
set -euo pipefail
tag="${1:?usage: bump-image.sh <image tag, e.g. sha-abc1234>}"
[[ "$tag" =~ ^[A-Za-z0-9._-]+$ ]] || { echo "not a valid image tag: $tag" >&2; exit 2; }
file=app/linkly/gitops/values.yaml
branch="${DEPLOY_BRANCH:-deploy}"   # the branch Argo CD deploys from
main="${MAIN_BRANCH:-main}"         # where the code comes from
bot=(-c user.name="github-actions[bot]" -c user.email="41898282+github-actions[bot]@users.noreply.github.com")

for attempt in 1 2 3; do
  git fetch -q origin "$main"
  src="${SOURCE_REF:-origin/$main}"
  if git ls-remote --exit-code --heads origin "$branch" >/dev/null; then
    git fetch -q origin "$branch"
    git switch -q -C "$branch" "origin/$branch"
    # deploy = main + tag: where they conflict, take main's side; the tag is rewritten just below.
    git "${bot[@]}" merge -q --no-edit -X theirs "$src" -m "deploy: merge $main"
    base="origin/$branch"
  else
    echo "no $branch branch yet: starting it from $main"
    git switch -q -C "$branch" "$src"
    base=""
  fi
  sed -i -E "s/^(  tag: ).*/\1${tag}/" "$file"
  grep -qx "  tag: ${tag}" "$file" || { echo "could not set image.tag in $file (is there a '  tag:' line?)" >&2; exit 1; }
  git diff --quiet -- "$file" || git "${bot[@]}" commit -q -m "deploy: linkly $tag" -- "$file"
  if [ -n "$base" ] && [ "$(git rev-parse HEAD)" = "$(git rev-parse "$base")" ]; then
    echo "$branch already deploys $tag with that commit of $main"; exit 0
  fi
  if git push -q origin "$branch"; then echo "$branch now deploys $tag"; exit 0; fi
  echo "$branch moved while we were working (attempt $attempt): starting again from the new tip" >&2
done
echo "could not update $branch after 3 attempts" >&2
exit 1
