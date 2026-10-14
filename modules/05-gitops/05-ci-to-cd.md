# From CI to CD

> **You need:** Lessons 3–4 · **Time:** ~60 min · **Start from:** `checkpoint/05-gitops`

## Why this matters

This is the payoff of Modules 2 to 5. You push a change to `main`, and a few minutes later it's
running in your cluster, tested, built, published and deployed, without anyone typing a deploy
command, and with every step recorded.

## Concept

The whole loop:

1. You merge a change into `main`.
2. CI runs lint, test, smoke and kubernetes (Module 4), then publishes images tagged `sha-<commit>`.
3. The **deploy** job runs `app/linkly/gitops/bump-image.sh sha-<commit>`, which:
   - merges **the commit that was just built and tested** (not whatever `main` is by now) into
     `deploy`, so chart changes arrive together with their image. Where `main` and `deploy`
     disagree, `main` wins: `deploy` is "`main` plus the tag", so a fix you make on `main` (say,
     to `values.yaml`'s image prefix) always reaches the cluster;
   - sets `image.tag` in `app/linkly/gitops/values.yaml` and commits `deploy: linkly sha-<commit>`
     as github-actions[bot];
   - pushes `deploy`. If `deploy` moved in the meantime, it starts again from the new tip
     (never a force push). If nothing changed, it does nothing.
4. Argo CD sees the new commit on `deploy` (within about three minutes, or on Refresh) and rolls
   the api, worker and web to the new images.

**Least privilege:** only the deploy job gets write access to the repository (`contents: write`);
every other job can only read. The script only touches `deploy`, although the token itself could
write to any unprotected branch, so it's worth adding a ruleset for `deploy` that blocks force
pushes and deletion. Nothing in CI holds credentials for your cluster.

The bump script has its own test, which runs against a throwaway Git repo standing in for GitHub.
It covers a first run with no `deploy` branch, a repeated tag, `main`'s changes arriving (and
winning), merging the built commit rather than a newer `main`, a push race and a rollback by revert:

```bash
app/linkly/gitops/test-bump-image.sh      # ... all bump-image tests passed
```

## Example

Make a change you can see. In `app/linkly/web/index.html`, change `<p>Paste a long link, get a
short one.</p>` to something of your own, then open a pull request and merge it into `main`. Then follow it:

```bash
gh run watch                                             # or the Actions tab: all jobs, then "deploy"
git fetch origin && git log --oneline -3 origin/deploy   # "deploy: linkly sha-…" by github-actions[bot]
kubectl -n argocd get application linkly                 # press Refresh in the UI to skip the wait
kubectl -n linkly get deploy web -o jsonpath='{.spec.template.spec.containers[0].image}'; echo
```

Reload http://localhost:8080: your text. The API reports which build it is:

```bash
kubectl -n linkly exec deploy/api -c api -- python -c "import urllib.request;print(urllib.request.urlopen('http://127.0.0.1:8000/healthz').read())"
# b'{"status":"ok","version":"sha-<your commit>"}'
```

## Lab

- [ ] Push a visible change to main and follow it through CI
- [ ] Find the deploy job's commit on the deploy branch
- [ ] Watch Argo CD roll out the new image
- [ ] Check the running version with /healthz
- [ ] Run the bump script's tests

## Check yourself

1. Why does the deploy job merge `main` into `deploy` instead of just changing the tag?

<details><summary>Answer</summary>

Argo CD deploys everything from `deploy`, chart included. Merging `main` brings chart changes
(new settings, new resources) along with the new image, so the two never get out of step.

</details>

2. Two merges to `main` finish at almost the same time. What stops them breaking `deploy`?

<details><summary>Answer</summary>

The deploy job's `concurrency` group runs them one at a time, and the script itself retries from
the new tip if `deploy` moved, merging rather than force-pushing, so no deployment is lost.

</details>
