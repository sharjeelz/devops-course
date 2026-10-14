#!/usr/bin/env bash
# Tests bump-image.sh against a throwaway bare repo standing in for GitHub (no network; everything
# happens in a temporary directory). Usage: app/linkly/gitops/test-bump-image.sh
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
fails=0
check() { local msg="$1"; shift; if "$@"; then echo "ok - $msg"; else echo "FAIL - $msg"; fails=$((fails + 1)); fi; }
g() { git -c user.name=t -c user.email=t@t "$@"; }

git init -q --bare "$tmp/origin.git"
git clone -q "$tmp/origin.git" "$tmp/work" 2>/dev/null
cd "$tmp/work"
mkdir -p app/linkly/gitops
cp "$here/values.yaml" "$here/bump-image.sh" app/linkly/gitops/
echo "chart v1" > CHART
g add . && g commit -q -m init && git push -q origin HEAD:main
on_deploy() { git -C "$tmp/origin.git" show "deploy:$1"; }
tag_on_deploy() { on_deploy app/linkly/gitops/values.yaml | sed -nE 's/^  tag: (.*)/\1/p'; }

# 1. First run in a fresh fork: no deploy branch yet. It's created from main and gets the tag.
app/linkly/gitops/bump-image.sh sha-aaaaaaa >/dev/null
check "creates the deploy branch and sets the tag" [ "$(tag_on_deploy)" = sha-aaaaaaa ]
check "deploy starts as main plus the tag" [ "$(on_deploy CHART)" = "chart v1" ]

# 2. A re-run with the same tag (and nothing new on main) makes no new commit.
before=$(git -C "$tmp/origin.git" rev-parse deploy)
app/linkly/gitops/bump-image.sh sha-aaaaaaa >/dev/null
check "the same tag twice makes no commit" [ "$(git -C "$tmp/origin.git" rev-parse deploy)" = "$before" ]

# 3. A change on main (e.g. the chart) reaches deploy with the next bump, and deploy keeps its tag
#    even though main's values.yaml still has the old one.
git switch -q -C main origin/main 2>/dev/null || git switch -q main
echo "chart v2" > CHART && g commit -q -am "chart v2" && git push -q origin main
app/linkly/gitops/bump-image.sh sha-ccccccc >/dev/null
check "main's changes are merged into deploy" [ "$(on_deploy CHART)" = "chart v2" ]
check "deploy has the new tag after merging main" [ "$(tag_on_deploy)" = sha-ccccccc ]
before=$(git -C "$tmp/origin.git" rev-parse deploy)

# 4. Race: someone pushes to deploy between our fetch and our push. A pre-push hook does exactly
#    that, once, so our first push is rejected and the script must start again from the new tip.
git clone -q "$tmp/origin.git" "$tmp/other" 2>/dev/null
cat > .git/hooks/pre-push <<HOOK
#!/usr/bin/env bash
[ -e "$tmp/raced" ] && exit 0
touch "$tmp/raced"
cd "$tmp/other" && git fetch -q origin && git switch -q -C deploy origin/deploy \
  && echo "someone else" > NOTE && git add NOTE \
  && git -c user.name=o -c user.email=o@o commit -q -m other && git push -q origin deploy
HOOK
chmod +x .git/hooks/pre-push
out=$(app/linkly/gitops/bump-image.sh sha-bbbbbbb 2>&1) || true
check "a push race happened and was retried" grep -q "moved while we were working" <<<"$out"
check "the new tag landed after the race" [ "$(tag_on_deploy)" = sha-bbbbbbb ]
check "the other person's commit was kept" git -C "$tmp/origin.git" cat-file -e deploy:NOTE
check "history was not rewritten (no force push)" git -C "$tmp/origin.git" merge-base --is-ancestor "$before" deploy
rm -f .git/hooks/pre-push

# 5. Rolling back = reverting the last bump commit on deploy.
git fetch -q origin deploy && git switch -q -C deploy origin/deploy
last_bump=$(git log --format=%H --grep '^deploy: linkly sha-bbbbbbb' -1)
g revert --no-edit "$last_bump" >/dev/null && git push -q origin deploy
check "reverting the bump commit puts the previous tag back" [ "$(tag_on_deploy)" = sha-ccccccc ]

# 6. A fix on main to values.yaml (e.g. the image prefix) reaches deploy: deploy is main + the tag.
git switch -q main && git pull -q --ff-only origin main
sed -i -E 's#^(  prefix: ).*#\1ghcr.io/newowner/#' app/linkly/gitops/values.yaml
g commit -q -am "fix prefix" && git push -q origin main
app/linkly/gitops/bump-image.sh sha-ddddddd >/dev/null
check "a prefix fix on main reaches deploy" grep -q "^  prefix: ghcr.io/newowner/" <(on_deploy app/linkly/gitops/values.yaml)
check "and deploy keeps its own tag" [ "$(tag_on_deploy)" = sha-ddddddd ]

# 7. CI deploys the commit it built, not whatever main is by now (SOURCE_REF).
git switch -q main
built=$(git rev-parse HEAD)
echo "untested chart" > CHART && g commit -q -am "untested change" && git push -q origin main
SOURCE_REF="$built" app/linkly/gitops/bump-image.sh sha-eeeeeee >/dev/null
check "merges the built commit, not a newer main" [ "$(on_deploy CHART)" = "chart v2" ]

# 8. If the tag line can't be found, fail loudly instead of reporting success.
git switch -q main && sed -i -E 's/^  tag:/    tag:/' app/linkly/gitops/values.yaml && g commit -q -am "reformat" && git push -q origin main
check "fails when it can't set the tag" bash -c '! app/linkly/gitops/bump-image.sh sha-fffffff >/dev/null 2>&1'

# 9. An invalid tag is refused before anything happens.
check "refuses an invalid tag" bash -c '! app/linkly/gitops/bump-image.sh "bad tag;rm" >/dev/null 2>&1'

[ "$fails" -eq 0 ] && echo "all bump-image tests passed" || { echo "$fails bump-image test(s) failed"; exit 1; }
