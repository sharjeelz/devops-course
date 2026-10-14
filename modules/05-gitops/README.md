# GitOps with Argo CD

> **You need:** Module 4, and your fork with Module 2's pipeline publishing images · **Time:** ~8 hours · **Start from:** `checkpoint/05-gitops`

So far *you* deployed Linkly: `kubectl apply`, `helm upgrade`. Every person or pipeline that
deploys needs cluster credentials, and nobody can say for sure what's running without looking.
GitOps turns it around. What should run is written in Git, and an agent *inside* the cluster
(Argo CD) keeps the cluster matching it, all the time. Deploying becomes a commit, and rolling
back becomes `git revert`. By the end of this module, a push to `main` reaches your cluster with
nobody running a deploy command.

## Before you start

1. **Bring in this module's files** (the Argo CD Application, the environment values, the bump
   script and the CI job):

   ```bash
   git switch main && git pull
   git checkout origin/checkpoint/06-aws -- app/linkly .github
   ```

   (No checkpoint branches in your fork? Use `upstream/` after
   `git remote add upstream https://github.com/sharjeelz/devops-course.git && git fetch upstream`.)
2. **Point them at your fork.** In `app/linkly/gitops/application.yaml`, change `repoURL` to
   `https://github.com/<you>/devops-course.git`. In `app/linkly/gitops/values.yaml`, change
   `prefix` to `ghcr.io/<you>/` (all lowercase), and `tag` to one of your published `sha-` tags.
3. **Commit to `main` through a pull request** (your checks run) and merge it. That merge is a
   push to `main`, so the pipeline runs, and its new **deploy** job creates the `deploy` branch for
   you (from the commit it just built). Wait for it, then check:
   `git fetch origin && git log --oneline -2 origin/deploy`. From then on CI keeps `deploy` up to
   date, and Argo CD deploys it.
4. **A cluster:** `kind create cluster --name linkly --config app/linkly/kind-config.yaml`. This
   time there's nothing to build or load: the cluster pulls your images from GHCR (they're public).

Everything runs on your machine and GitHub's free tier. The GitOps environment uses the chart's
local Postgres password, which is fine for kind and never for real; Module 8 handles real secrets.

## Lessons

1. [Why GitOps](01-why-gitops.md): push vs pull, and the four principles
2. [Installing Argo CD](02-install-argo-cd.md): the parts, the UI, the first login
3. [Your first Application](03-first-application.md): Linkly deployed from Git
4. [Self-healing](04-self-healing.md): drift, selfHeal and prune
5. [From CI to CD](05-ci-to-cd.md): a push to main reaches the cluster by itself
6. [Rollback and promotion](06-rollback-and-promotion.md): undo with Git, add environments
7. [Landscape: GitOps and delivery tools](07-landscape.md): Flux, push-based CD and more

By the end, `checkpoint/06-aws` holds Linkly with its GitOps setup: where Module 6 starts.
