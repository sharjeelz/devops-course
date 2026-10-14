# Module 5 (GitOps with Argo CD) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Git becomes the source of truth for what runs. Argo CD, running in the kind cluster, keeps Linkly in sync with the repo. After every successful build of `main`, CI records the new image tag on a `deploy` branch, and Argo CD rolls it out with no `kubectl` or `helm` from a person. Seven lessons teach it.

**Architecture:**
- **Argo CD v3.5.5** is installed from its upstream manifest into namespace `argocd`.
- **One multi-source Application** (`app/linkly/gitops/application.yaml`) has two sources:
  - the Helm chart, taken from `main` (`app/linkly/helm/linkly`);
  - the environment values file `app/linkly/gitops/values.yaml`, taken from the `deploy` branch through `ref: deploy` / `$deploy/...`.
- **Sync policy:** automated, with prune and selfHeal; it creates the namespace.
- **Why a `deploy` branch:**
  - Its history *is* the deployment log, and `git revert` there is a rollback.
  - It keeps CI from pushing to `main`, which Module 2's ruleset protects with required checks.
- **New CI job `deploy`.** It runs after `publish`, only for pushes to `main`, with `contents: write`. It runs `app/linkly/gitops/bump-image.sh sha-<7>`, which:
  1. checks out (or creates) `deploy`;
  2. sets `image.tag`;
  3. commits as github-actions[bot];
  4. pushes, rebasing and retrying if `deploy` moved.

  It does nothing if the tag is already set. Pushes made with `GITHUB_TOKEN` don't trigger workflows, and the workflow only runs on `main` and tags anyway, so there are no loops.

**Tech Stack:** Argo CD v3.5.5 (Application CRD, multi-source, automated sync), kind v0.33.0, Helm chart from Module 4, GitHub Actions, bash.

**Spec:** `docs/superpowers/specs/2026-10-14-course-design.md`, module map row 5: "Git is the source of truth; CI bumps the image tag, Argo syncs it; full CI/CD locally; landscape: Flux, push-based CD".

## Global Constraints

- **Lesson format:** as before, and every header says "Start from: `checkpoint/05-gitops`". The README brings files in from `checkpoint/06-aws`.
- **Learners deploy their own fork.** `application.yaml`'s `repoURL` and `gitops/values.yaml`'s `image.prefix` name `sharjeelz` with a comment to change them, and the README says so first.
- **No secrets in Git.** The GitOps environment is the local kind cluster, so it keeps the chart's default local Postgres password, and the README and lessons say so. Real secrets come in Module 8.
- **Least privilege in CI:** only the `deploy` job gets `contents: write`, and it never touches `main`.
- **This plan does not push to `main`.** Live verification may push the `module-5` branch and a temporary branch, which is deleted afterwards and ledgered.
- **Commits** end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **The bump script against a `deploy` branch that doesn't exist yet**, which is the first run in a fresh fork. It must be created from `main`. Pinned in Task 2 (local test against a bare repo).
2. **Two `main` runs racing to push `deploy`.** The second must rebase and retry, not fail or force-push. Pinned in Task 2 (simulated by pushing a competing commit first).
3. **The same tag twice** (a re-run). No empty commit. Pinned in Task 2.
4. **Drift on the cluster** (someone runs `kubectl scale` or deletes a Service). selfHeal reverts it. Pinned in Task 3 (live).
5. **Rollback through Git** (`git revert` of a bump on `deploy`). Argo CD returns to the previous image. Pinned in Task 3 (live).

---

### Task 1: GitOps files

`app/linkly/gitops/values.yaml`:

```yaml
# The environment Argo CD deploys (module 5): your local kind cluster, running the images your
# pipeline published. On the "deploy" branch, CI sets image.tag after every successful build of
# main, and Argo CD rolls it out. To change what runs, change this file on "deploy" (a revert there
# is a rollback). Change the prefix to your own GHCR namespace.
# The database keeps the chart's local default password: fine for kind, never for real (module 8).
image:
  prefix: ghcr.io/sharjeelz/
  tag: sha-85779b4
```

`app/linkly/gitops/application.yaml`:

```yaml
# Linkly, managed by Argo CD (module 5). Two sources: the chart from main, and the environment's
# values from the "deploy" branch ($deploy). Change both repoURLs to your fork.
#   kubectl apply -f app/linkly/gitops/application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: linkly
  namespace: argocd
spec:
  project: default
  sources:
    - repoURL: https://github.com/sharjeelz/devops-course.git
      targetRevision: main
      path: app/linkly/helm/linkly
      helm:
        valueFiles:
          - $deploy/app/linkly/gitops/values.yaml
    - repoURL: https://github.com/sharjeelz/devops-course.git
      targetRevision: deploy
      ref: deploy
  destination:
    server: https://kubernetes.default.svc
    namespace: linkly
  syncPolicy:
    automated:
      prune: true        # objects removed from Git are removed from the cluster
      selfHeal: true     # changes made by hand on the cluster are put back
    syncOptions:
      - CreateNamespace=true
```

- [ ] Check: `kubectl apply --dry-run=server` against a cluster with Argo CD installed is accepted.
- [ ] Commit: `feat(linkly): Argo CD Application and the GitOps environment values`.

### Task 2: The bump script (TDD)

`app/linkly/gitops/bump-image.sh`, run from the repo root, `./app/linkly/gitops/bump-image.sh sha-abc1234`:

```bash
#!/usr/bin/env bash
# Records a new image tag on the "deploy" branch, the branch Argo CD watches for values (module 5).
# Run by CI after a successful build of main; safe to run again (no change = no commit).
# Usage: app/linkly/gitops/bump-image.sh sha-<7 chars>    (from the repo root, origin = your repo)
set -euo pipefail
tag="${1:?usage: bump-image.sh <image tag, e.g. sha-abc1234>}"
[[ "$tag" =~ ^[A-Za-z0-9._-]+$ ]] || { echo "not a valid image tag: $tag" >&2; exit 2; }
file=app/linkly/gitops/values.yaml
branch=deploy
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
```

Test, `app/linkly/gitops/test-bump-image.sh`. It runs entirely in a temporary directory, with a bare repo standing in for GitHub:

```bash
#!/usr/bin/env bash
# Tests bump-image.sh against a throwaway bare repo (no network, nothing outside a temp dir).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
git init -q --bare "$tmp/origin.git"
git clone -q "$tmp/origin.git" "$tmp/work" 2>/dev/null
cd "$tmp/work"
mkdir -p app/linkly/gitops && cp "$here/values.yaml" app/linkly/gitops/ && cp "$here/bump-image.sh" app/linkly/gitops/
git -c user.name=t -c user.email=t@t add . && git -c user.name=t -c user.email=t@t commit -q -m init && git push -q origin HEAD:main
tagof() { git -C "$tmp/origin.git" show "deploy:app/linkly/gitops/values.yaml" | sed -nE 's/^  tag: (.*)/\1/p'; }
ok() { echo "ok - $*"; }

# 1. No deploy branch yet: it's created and gets the tag.
app/linkly/gitops/bump-image.sh sha-aaaaaaa >/dev/null
[ "$(tagof)" = sha-aaaaaaa ] && ok "creates deploy and sets the tag"

# 2. Same tag again: no new commit.
before=$(git -C "$tmp/origin.git" rev-parse deploy)
app/linkly/gitops/bump-image.sh sha-aaaaaaa >/dev/null
[ "$(git -C "$tmp/origin.git" rev-parse deploy)" = "$before" ] && ok "same tag twice makes no commit"

# 3. deploy moved underneath us: the script rebases onto it and still lands its tag.
git clone -q "$tmp/origin.git" "$tmp/other" 2>/dev/null
( cd "$tmp/other" && git switch -q deploy && echo "# someone else" >> README-deploy && git add README-deploy \
  && git -c user.name=o -c user.email=o@o commit -q -m other && git push -q origin deploy )
git switch -q main 2>/dev/null || git switch -q -c main origin/main
git update-ref refs/remotes/origin/deploy "$before"      # our view of deploy is now stale
app/linkly/gitops/bump-image.sh sha-bbbbbbb >/dev/null
[ "$(tagof)" = sha-bbbbbbb ] && git -C "$tmp/origin.git" show deploy:README-deploy >/dev/null && ok "keeps others' commits and lands the new tag"

# 4. A bad tag is refused.
! app/linkly/gitops/bump-image.sh 'bad tag;rm' 2>/dev/null && ok "refuses an invalid tag"
echo "all bump-image tests passed"
```

- [ ] **RED:** write the test first and run it. Expected: it fails because `bump-image.sh` doesn't exist (cp fails).
- [ ] **GREEN:** add the script and run the test. Expected: four `ok` lines and "all bump-image tests passed".
- [ ] Commit: `feat(linkly): bump-image.sh records a new image tag on the deploy branch (tested against a bare repo)`.

### Task 3: CI job and live verification

Add to `.github/workflows/ci.yml`:

```yaml
  deploy:
    needs: publish
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    runs-on: ubuntu-24.04
    permissions:
      contents: write          # to push the deploy branch, and only this job
    concurrency:
      group: deploy-branch
      cancel-in-progress: false
    steps:
      - uses: actions/checkout@v7
        with:
          fetch-depth: 0
      - name: Point the deploy branch at this build
        run: app/linkly/gitops/bump-image.sh "sha-${GITHUB_SHA::7}"
```

- [ ] actionlint: 0 findings.
- [ ] **Live, on a kind cluster with Argo CD v3.5.5.** Push the `module-5` branch, plus a temporary branch `gitops-test` (created from `module-5`) standing in for `deploy`. Then apply the Application with both `targetRevision`s pointed at those branches. Expected:
  - **Synced Healthy.**
  - **Drift reverted:** `kubectl scale deploy/api --replicas=1` goes back to 2, and a deleted `web` Service is recreated.
  - **Bump rolls out:** running `bump-image.sh` against `gitops-test` (with a temporary edit of `branch=`) to a different published tag makes Argo roll the api to that image after a refresh.
  - **Revert rolls back:** a `git revert` of that bump on `gitops-test` rolls it back.
  - Ledger every result. Afterwards delete `gitops-test` on GitHub.
- [ ] Commit: `ci: after publishing main, point the deploy branch at the new build (GitOps)`.

### Task 4: Lessons

Write `modules/05-gitops/README.md` and seven lessons, each with Example commands verified live (ledgered), Lab items and Check-yourself answers.

- **README:**
  - **You need:** Module 4, plus your fork with Module 2's pipeline publishing images.
  - **Set up:**
    - bring the files in from `checkpoint/06-aws`;
    - change `repoURL` (×2) and `image.prefix` to your fork;
    - commit and push `main`;
    - create `deploy` with `git push origin main:deploy`.
  - **The kind cluster:** it pulls your GHCR images (public). Free.
- **01-why-gitops:**
  - **Concept:** push-based (CI runs `helm upgrade`, as in Module 4) versus pull-based (an agent in the cluster pulls from Git); the four OpenGitOps principles (declarative, versioned and immutable, pulled automatically, continuously reconciled); Git as the audit log and the rollback button; what changes for credentials (CI no longer needs cluster access).
  - **Lab:**
    - Explain push vs pull deployment
    - Name the four GitOps principles
    - List who can change production today, and how
  - **Check yourself:** why CI not holding cluster credentials matters.
- **02-install-argo-cd:**
  - **Concept:** the parts (API server and UI, repo-server, application-controller, ApplicationSet controller, Redis, Dex); the initial admin password Secret; the UI; the CLI (optional).
  - **Example:** install (`--server-side --force-conflicts`), wait, `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d`, `kubectl -n argocd port-forward svc/argocd-server 8443:443`, log in at https://localhost:8443 (self-signed certificate warning).
  - **Lab:**
    - Install Argo CD in your cluster
    - Find the initial admin password
    - Log in to the UI
    - Name what each Argo CD pod does
- **03-first-application:**
  - **Concept:** the Application resource (source, destination, project, syncPolicy); multi-source with `ref` and `$deploy`; sync status vs health status.
  - **Example:**
    1. `kubectl apply -f app/linkly/gitops/application.yaml`.
    2. Watch it in the UI and with `kubectl -n argocd get application linkly`.
    3. Open Linkly on localhost:8080. The gitops values keep the NodePort front door, and the kind config maps it.
  - **Lab:**
    - Point the Application at your fork and apply it
    - Find the sync status and the health status
    - Follow which source each value came from
    - Open Linkly deployed by Argo CD
- **04-self-healing:**
  - **Concept:** automated sync, selfHeal, prune; drift; why hand edits get reverted.
  - **Example:**
    - `kubectl -n linkly scale deploy/api --replicas=1`, then watch it return to 2.
    - `kubectl -n linkly delete svc web`, then watch it return.
    - Prune: delete an object from the chart on `main` (shown, not required).
  - **Lab:**
    - Scale the API by hand and watch Argo CD undo it
    - Delete the web Service and watch it come back
    - Explain what prune would do if you deleted a template
    - Turn selfHeal off and see drift stay
  - **Check yourself:** why selfHeal is a feature, not an annoyance.
- **05-ci-to-cd:**
  - **Concept:** the whole loop (push to main → lint/test/smoke/kubernetes → publish → deploy job commits the tag to `deploy` → Argo CD notices, polling about every 3 minutes or on refresh → rolling update); `bump-image.sh` explained; why a separate branch; least privilege.
  - **Example:** a visible change to Linkly's page (title text) pushed to `main` and followed through to the cluster; `kubectl -n linkly get deploy api -o jsonpath=...image`; refresh in the UI.
  - **Lab:**
    - Push a visible change to main and follow it through CI
    - Find the deploy job's commit on the deploy branch
    - See Argo CD roll out the new image
    - Check the running version with /healthz
- **06-rollback-and-promotion:**
  - **Concept:** rollback = `git revert` on `deploy` (not `kubectl`, not the Argo CD UI rollback, which auto-sync forbids); promotion between environments by changing an environment's file (e.g. a second Application for "prod" reading `gitops/values-prod.yaml`, promoted by pull request); ApplicationSet in brief.
  - **Example:** `git switch deploy && git pull && git revert --no-edit HEAD && git push`, then watch Argo CD go back; `/healthz` shows the old version.
  - **Lab:**
    - Roll back by reverting the last deploy commit
    - Confirm the old version is running again
    - Sketch how you'd add a second environment
    - Explain why rolling back in the UI isn't allowed here
- **07-landscape:**
  - **Concept:** Flux (v2.9, controllers per concern, `GitRepository`/`HelmRelease`/`Kustomization`, image automation); push-based CD still common (and Module 4's `helm upgrade`); Argo CD Image Updater; progressive delivery (Argo Rollouts, Flagger); promotion tools (Kargo); hosted options.
  - **Example:** a Flux HelmRelease sketch for Linkly, not run.
  - **Lab:**
    - Compare Argo CD and Flux in three points
    - Explain when push-based CD is enough
    - Name one progressive delivery tool
- [ ] The format check passes; the live Course API lists the module (read-only). Commit: `docs(module-5): GitOps with Argo CD - why, install, first application, self-healing, CI to CD, rollback and promotion, landscape`.

### Task 5: Checkpoint for Module 6

- [ ] `git branch checkpoint/06-aws HEAD`; update the README checkpoint sentence; commit `docs: checkpoint branch for module 6`.
