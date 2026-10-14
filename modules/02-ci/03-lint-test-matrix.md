# Lint, test, and a matrix

> **You need:** Lesson 2 · **Time:** ~75 min · **Start from:** `checkpoint/02-ci`

## Why this matters

One job testing one service is a start. A real pipeline also checks code style and obvious
mistakes (lint), tests every service, does it in parallel so it stays fast, reuses work between
runs, and stops anyone from merging a red change into `main`.

## Concept

- **Lint:** a tool reads the code without running it and flags mistakes and inconsistencies.
  Linkly uses **Ruff**, configured in `app/linkly/ruff.toml`. The same file is used by your
  editor and by CI, so they never disagree.
- **Matrix:** `strategy.matrix` runs one job definition several times with different values.
  `service: [api, worker]` becomes two parallel jobs, `test (api)` and `test (worker)`.
- **Build cache:** `docker/build-push-action` with `cache-from/cache-to: type=gha` stores image
  layers in GitHub's cache, so the next run skips the `pip install` layers that didn't change.
- **Required checks:** a branch rule on `main` that blocks merging until named checks pass.

## Example

Replace the `jobs:` section of your `ci.yml` with:

```yaml
jobs:
  lint:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v7
      - uses: astral-sh/ruff-action@v3
        with:
          version: "0.17.0"
          src: app/linkly

  test:
    runs-on: ubuntu-24.04
    strategy:
      matrix:
        service: [api, worker]
    steps:
      - uses: actions/checkout@v7
      - uses: docker/setup-buildx-action@v4
      - name: Build the test stage
        uses: docker/build-push-action@v7
        with:
          context: app/linkly/${{ matrix.service }}
          target: test
          load: true
          tags: linkly-${{ matrix.service }}:test
          cache-from: type=gha,scope=${{ matrix.service }}-test
          cache-to: type=gha,mode=max,scope=${{ matrix.service }}-test
      - name: Run the tests
        run: docker run --rm linkly-${{ matrix.service }}:test
```

Add `app/linkly/ruff.toml`:

```toml
line-length = 120
target-version = "py312"

[lint]
select = ["E", "F", "I", "B", "UP"]
```

Push. **The lint job fails**, and that's the point: `checkpoint/02-ci` has 9 findings (import
order, `datetime.UTC`, `collections.abc`, long lines). Fix them:

```bash
pip install ruff==0.17.0
ruff check --fix app/linkly      # fixes the automatic ones
ruff check app/linkly            # the rest: wrap the long lines by hand
```

Push again: lint passes, and the two test jobs run side by side.

**Protect `main`:** in your fork, *Settings → Rules → Rulesets → New branch ruleset*, target
the default branch, turn on **Require status checks to pass**, and add `lint`, `test (api)` and
`test (worker)`. (Older repos show this under *Settings → Branches → Add branch protection rule*.)

## Lab

- [ ] Add the lint job and watch it fail
- [ ] Fix the findings until lint passes
- [ ] Turn the test job into a matrix over api and worker
- [ ] Compare a cached and an uncached run's build time
- [ ] Require the checks before merging into main

Hint for the cache: the first run after adding `cache-to` fills the cache; push an unrelated
change (e.g. to a lesson file) and compare the **Build the test stage** times.

## Check yourself

1. If everyone's editor already runs the linter, why run it in CI too?

<details><summary>Answer</summary>

Not everyone's editor does, or with the same settings. CI is the one place that checks every
change with the agreed rules, so nothing slips through.

</details>

2. What does `matrix: service: [api, worker]` do?

<details><summary>Answer</summary>

It creates two copies of the job, one with `matrix.service` set to `api` and one to `worker`,
and runs them in parallel on separate runners.

</details>

3. What does the `type=gha` cache store, and what does it save?

<details><summary>Answer</summary>

Image layers from the build. A later run reuses layers whose inputs didn't change (the
dependency install, mostly), so only the changed layers rebuild.

</details>
