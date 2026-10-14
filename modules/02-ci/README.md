# CI with GitHub Actions

> **You need:** Module 1, a GitHub account, and your fork of this repo · **Time:** ~8 hours · **Start from:** `checkpoint/02-ci`

In Module 1 you could build and check Linkly with a couple of commands, but only if somebody
remembers to run them. This module makes GitHub do it on every push and pull request: lint the
code, run the tests inside their own images, start the whole stack and use it, and, when it all
passes, publish Linkly's images to a registry with versions you can trace.

## Before you start

- **Turn on Actions in your fork.** Forks start with workflows switched off: open your fork's
  **Actions** tab and click **"I understand my workflows, go ahead and enable them"**.
- **Start from the checkpoint:** `git switch -c module-2 checkpoint/02-ci` gives you Linkly as
  Module 1 left it, with no workflow yet. You'll write `.github/workflows/ci.yml` lesson by lesson.

**Cost:** Actions is free for public repositories. Private repositories use a monthly allowance
of free minutes, more than enough for this module.

## Lessons

1. [Why CI](01-why-ci.md): what a pipeline is for, run by hand first
2. [Your first workflow](02-first-workflow.md): workflows, jobs, steps, runners
3. [Lint, test, and a matrix](03-lint-test-matrix.md): fail fast, run in parallel, cache, protect main
4. [The whole stack in CI](04-smoke-in-ci.md): job order, the smoke test, cancelling stale runs
5. [Publishing images to GHCR](05-publish-to-ghcr.md): a registry, tokens and least privilege
6. [Versions you can trace](06-versioning.md): tags, semver, and "which version is running?"
7. [Landscape: CI beyond GitHub Actions](07-landscape.md): Jenkins, GitLab CI and friends

By the end, `checkpoint/03-kubernetes` holds Linkly with its pipeline: where Module 3 starts.
