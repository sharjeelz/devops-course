# Rollback and promotion

> **You need:** Lesson 5 · **Time:** ~45 min · **Start from:** `checkpoint/05-gitops`

## Why this matters

Something bad reaches the cluster. In a GitOps setup the fix isn't `kubectl` or a button: it's
the same thing as any other change, a commit. That means rollbacks are reviewed, recorded and
repeatable. The same idea extends to several environments: moving a version from one to the next
is a commit too.

## Concept

- **Rollback = `git revert` on `deploy`.** Reverting a `deploy: linkly sha-…` commit puts the
  previous tag back, and Argo CD rolls back to it. The revert stays in history, so you can see
  that a rollback happened, and why.
- **Why not Argo CD's own "rollback" button?** With automated sync on, Argo CD refuses it,
  because the next sync would immediately re-apply what Git says. Git stays the truth.
- **A rollback holds only until the next successful push to `main`.** *Any* merge (even a docs
  change) builds a new image from `main`, which still contains the bad code, and rolls `deploy`
  forward to it. So roll back to stop the damage, then fix `main` quickly (or revert the bad
  change on `main` too).
- **Reverting a `deploy: linkly sha-…` commit restores only the image tag.** If the same run also
  merged chart changes (the `deploy: merge main` commit just before it), those stay, and the old
  image runs with the new chart. Usually fine; if the chart change is the problem, revert it on `main`.
- **Don't revert a `deploy: merge main` commit by hand.** It needs `git revert -m 1`, and
  afterwards later merges of `main` won't bring those changes back (Git thinks they're already in).
  Fix the chart on `main` instead.
- **Promotion between environments:** add a second Application (say `linkly-prod`, in its own
  namespace or cluster) that reads its own values file (`app/linkly/gitops/values-prod.yaml`).
  Promoting is copying a tested tag into that file through a pull request, reviewed and reversible.
- **ApplicationSet** generates many similar Applications from one template, for example one
  per environment folder or per cluster, when hand-writing them gets repetitive.

## Example

Roll back the latest deployment:

```bash
git fetch origin && git switch deploy && git pull
git log --oneline -3                                     # the newest "deploy: linkly sha-…" first
git revert --no-edit <that commit>
git push origin deploy
kubectl -n argocd get application linkly                 # Refresh in the UI to skip the wait
kubectl -n linkly get deploy api -o jsonpath='{.spec.template.spec.containers[0].image}'; echo
```

On the author's machine, Argo CD rolled the api back to the previous image about 4 seconds after
a refresh.

## Lab

- [ ] Roll back by reverting the last deploy commit
- [ ] Confirm the previous version is running again
- [ ] Sketch how you'd add a second environment
- [ ] Explain why Argo CD's rollback button is disabled here

## Check yourself

1. Why is a rollback by `git revert` better than `kubectl set image`?

<details><summary>Answer</summary>

It's recorded (who, when, why), reviewable, and it actually sticks: Argo CD would undo a
`kubectl` change within seconds, because Git still says otherwise.

</details>

2. You rolled back, then a teammate merges a README change to `main`. What happens?

<details><summary>Answer</summary>

CI builds and publishes a new image from `main` (which still has the bad code) and the deploy job
moves `deploy` to it, so the problem comes back. A rollback buys time; the real fix (or a revert)
has to land on `main`.

</details>

3. How would you promote a version from dev to prod?

<details><summary>Answer</summary>

Open a pull request that sets prod's values file to the tag that's proven itself in dev. When
it's merged, prod's Application syncs it. The promotion is reviewed and can be reverted like any commit.

</details>
