# Why CI

> **You need:** Module 1 · **Time:** ~45 min · **Start from:** `checkpoint/02-ci`

## Why this matters

"Did you run the tests before merging?" is a question nobody should have to ask. Without
automation, someone forgets, a broken change lands on `main`, and three days later a teammate
spends a morning finding out which commit broke what. **Continuous integration** means every
change is checked automatically, the same way, within minutes, before it's merged.

## Concept

- **CI (continuous integration):** every push and pull request is built and tested
  automatically, so `main` always works.
- **CD (continuous delivery / deployment):** once CI passes, the result is packaged and
  delivered: published as images (this module), and later deployed (Module 5).
- **A pipeline is stages that gate each other.** Cheap, fast checks first; slow, thorough ones
  only if those pass:

```
lint ──┐
       ├──▶ smoke (whole stack) ──▶ publish images
test ──┘   (api, worker in parallel)
```

- **Fast feedback:** a failure in two minutes, while you still remember what you changed, is
  worth ten times a failure found next week.
- **Same steps, every time:** CI runs the commands you'd run by hand, but it never forgets one
  and never uses a different version on a different laptop.

## Example

Run Linkly's whole pipeline by hand, from the repo root, exactly as CI will:

```bash
pip install ruff==0.17.0
ruff check app/linkly                                                     # lint
docker build --target test -t linkly-api:test app/linkly/api && docker run --rm linkly-api:test
docker build --target test -t linkly-worker:test app/linkly/worker && docker run --rm linkly-worker:test
app/linkly/smoke-test.sh                                                  # the whole stack
```

On `checkpoint/02-ci`, even Ruff's default rules find 5 problems (import order, an old way to
import `Callable`, a `datetime` shortcut). Leave them for now: lesson 3 adds the course's own
lint rules, which find a few more, and makes CI catch them all.

## Lab

- [ ] Run each pipeline stage by hand
- [ ] Time the whole pipeline from lint to smoke
- [ ] Break a test on purpose and note which stage catches it
- [ ] List which of these steps you'd forget to run before a merge

Hint for timing: prefix each command with `time`, or use `date +%s` before and after.

## Check yourself

1. What's the difference between CI and CD?

<details><summary>Answer</summary>

CI checks every change automatically (build, lint, test) so the main branch keeps working. CD
takes what passed and delivers it: publishing artifacts, and in continuous *deployment*,
releasing them to an environment without a manual step.

</details>

2. Why run lint and unit tests before the smoke test?

<details><summary>Answer</summary>

They're fast and cheap. If they fail, there's no point spending minutes starting the whole
stack, and the failure points straight at the problem.

</details>

3. What does "fast feedback" actually buy a team?

<details><summary>Answer</summary>

Problems are found while the change is fresh in the author's head and before others build on
it, so they're cheaper to fix and `main` stays usable for everyone.

</details>
