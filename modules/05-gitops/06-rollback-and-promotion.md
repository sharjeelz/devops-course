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
- **The next good build moves on again:** after you fix `main`, CI bumps `deploy` to the new
  build as usual.
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

2. How would you promote a version from dev to prod?

<details><summary>Answer</summary>

Open a pull request that sets prod's values file to the tag that's proven itself in dev. When
it's merged, prod's Application syncs it. The promotion is reviewed and can be reverted like any commit.

</details>
