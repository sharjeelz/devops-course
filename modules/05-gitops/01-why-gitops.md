# Why GitOps

> **You need:** the module README's setup · **Time:** ~40 min · **Start from:** `checkpoint/05-gitops`

## Why this matters

Ask "what's running in production, and who changed it last?" In most teams, the honest answer
involves someone's terminal history. And every place that can deploy (each engineer's laptop, the
CI system) holds credentials that can change the cluster. GitOps makes Git the single place where
the desired state lives, and a process inside the cluster the only thing that applies it.

## Concept

- **Push-based deployment:** something outside the cluster *pushes* changes in: you running
  `helm upgrade`, or a CI job doing it. CI needs credentials for the cluster, and if someone
  changes the cluster by hand, nothing notices.
- **Pull-based (GitOps):** an agent *inside* the cluster *pulls* the desired state from Git and
  applies it. CI only needs to write to Git; nothing outside the cluster can change it.
- **The four OpenGitOps principles:**
  1. **Declarative:** the system is described as data (our chart and values), not as scripts of steps.
  2. **Versioned and immutable:** that description lives in Git, with full history.
  3. **Pulled automatically:** software agents fetch it; nobody runs `apply`.
  4. **Continuously reconciled:** the agent keeps comparing actual with desired, and fixes drift.
- **What you get:** an audit log (Git history: who changed what, when, why, reviewed in a pull
  request), rollback by `git revert`, and a cluster you can rebuild from the repo alone.

How it works for Linkly in this module:

```
push to main ─▶ CI: lint, test, smoke, kubernetes ─▶ publish images ─▶ deploy job:
                                                     commit "image.tag = sha-abc1234" to the deploy branch
                                                                         │
                         Argo CD (in the cluster) ◀── watches deploy ────┘
                         └─▶ rolling update to the new image
```

## Example

There's nothing to run yet; look at what's about to drive your cluster:

```bash
cat app/linkly/gitops/application.yaml      # what to deploy, from where, and how to keep it in sync
cat app/linkly/gitops/values.yaml           # which images run in this environment
git log --oneline origin/deploy | head      # once deploy exists: the deployment history
```

## Lab

- [ ] Explain push-based and pull-based deployment in your own words
- [ ] Name the four GitOps principles
- [ ] List everyone and everything that can change your cluster today

## Check yourself

1. Why does it matter that CI no longer needs credentials for the cluster?

<details><summary>Answer</summary>

CI systems run lots of third-party code and are a favourite target. If CI can only write to Git,
compromising it doesn't hand over the cluster, and every change it makes is visible and revertible in Git.

</details>

2. What does "continuously reconciled" add over "deployed from Git once"?

<details><summary>Answer</summary>

Drift gets fixed. If someone or something changes the cluster by hand, the agent notices the
difference from Git and puts it back, so Git stays the truth instead of a historical record.

</details>
