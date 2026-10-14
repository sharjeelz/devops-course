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
g add . && g commit -q -m init && git push -q origin HEAD:main
tag_on_deploy() { git -C "$tmp/origin.git" show "deploy:app/linkly/gitops/values.yaml" | sed -nE 's/^  tag: (.*)/\1/p'; }

# 1. First run in a fresh fork: no deploy branch yet. It's created and gets the tag.
app/linkly/gitops/bump-image.sh sha-aaaaaaa >/dev/null
check "creates the deploy branch and sets the tag" [ "$(tag_on_deploy)" = sha-aaaaaaa ]

# 2. A re-run with the same tag makes no new commit.
before=$(git -C "$tmp/origin.git" rev-parse deploy)
app/linkly/gitops/bump-image.sh sha-aaaaaaa >/dev/null
check "the same tag twice makes no commit" [ "$(git -C "$tmp/origin.git" rev-parse deploy)" = "$before" ]

# 3. Race: someone pushes to deploy between our fetch and our push. A pre-push hook does exactly
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

# 4. An invalid tag is refused before anything happens.
check "refuses an invalid tag" bash -c '! app/linkly/gitops/bump-image.sh "bad tag;rm" >/dev/null 2>&1'

[ "$fails" -eq 0 ] && echo "all bump-image tests passed" || { echo "$fails bump-image test(s) failed"; exit 1; }
