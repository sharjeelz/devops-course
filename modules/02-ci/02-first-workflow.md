# Your first workflow

> **You need:** Lesson 1, Actions enabled on your fork · **Time:** ~60 min · **Start from:** `checkpoint/02-ci`

## Why this matters

GitHub Actions runs your pipeline on GitHub's machines whenever something happens in your
repository. Before building the full pipeline, get one small job running and learn to read
what it tells you: most CI time in real life is spent reading logs of failed runs.

## Concept

- **Workflow:** a YAML file in `.github/workflows/`. A repo can have several.
- **Event (`on:`):** what starts it: `push`, `pull_request`, a schedule, a manual button.
- **Job:** a set of steps that runs on one **runner**, a fresh virtual machine GitHub starts for
  you (`runs-on: ubuntu-24.04`) and throws away afterwards. Jobs run in parallel unless told otherwise.
- **Step:** either `run:` (a shell command) or `uses:` (an **action**, a reusable step someone
  published, like `actions/checkout`, which fetches your code onto the runner).
- **`permissions:`:** what the job's automatic token may do. Start with read-only.

## Example

Create `.github/workflows/ci.yml`:

```yaml
name: CI

on: [push, pull_request]

permissions:
  contents: read

jobs:
  test:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v7
      - name: Build the API's test image
        run: docker build --target test -t linkly-api:test app/linkly/api
      - name: Run the tests
        run: docker run --rm linkly-api:test
```

The runner already has Docker, so the test stage from Module 1 just works.

```bash
git add .github/workflows/ci.yml
git commit -m "ci: run the API tests"
git push -u origin module-2
```

Open your fork's **Actions** tab: there's a run named after your commit. Click into the `test`
job and expand **Run the tests**: you'll see the same `15 passed` as on your machine.

## Lab

- [ ] Enable Actions on your fork
- [ ] Add a one-job workflow that runs the API tests
- [ ] Push and find the run in the Actions tab
- [ ] Read the log of the test step
- [ ] Make the run fail on purpose and read why

Hint for the failure: change an expected value in `app/linkly/api/tests/test_codes.py`, push,
and find the `AssertionError` in the log. The commit gets a red ✗ on GitHub. Then revert it.

## Check yourself

1. What's the difference between a job and a step?

<details><summary>Answer</summary>

A job runs on its own fresh runner and contains steps; steps run one after another on that same
runner and share its files. Separate jobs share nothing unless you pass it explicitly.

</details>

2. When do you write `uses:` and when `run:`?

<details><summary>Answer</summary>

`uses:` runs a published action (checkout, login to a registry, build with caching). `run:`
runs your own shell command. Prefer plain `run:` when the command is simple.

</details>

3. Where does the runner come from, and what's on it afterwards?

<details><summary>Answer</summary>

GitHub starts a fresh virtual machine for each job and deletes it when the job ends. Nothing
carries over to the next run unless you use caches or artifacts.

</details>
