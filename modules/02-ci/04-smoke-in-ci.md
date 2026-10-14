# The whole stack in CI

> **You need:** Lesson 3 · **Time:** ~45 min · **Start from:** `checkpoint/02-ci`

## Why this matters

Unit tests prove each part works on its own. They can't catch a typo in `nginx.container.conf`,
a wrong port in `compose.yaml`, or the worker and the API disagreeing about the queue name. The
smoke test from Module 1 checks the whole stack the way a user would. In CI, it becomes the gate
before anything is published.

## Concept

- **`needs:`** turns parallel jobs into a graph: `smoke` starts only when `lint` and `test`
  have passed. GitHub draws the graph on the run's summary page.
- **Runners have Docker and Compose,** so `smoke-test.sh` runs unchanged. It uses its own
  project name and port (18080), so nothing on the runner gets in its way.
- **`concurrency`:** runs for the same branch form a group. When you push twice to a work
  branch, the first run is pointless, and cancelling it saves runners. On `main` we *don't*
  cancel: lesson 5's publish must never be cut off halfway (two images new, one old). So main's
  runs queue up and finish in order. That's what
  `cancel-in-progress: ${{ github.ref != 'refs/heads/main' }}` says.

## Example

Add to `ci.yml`, at the top level (next to `permissions:`):

```yaml
concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: ${{ github.ref != 'refs/heads/main' }}
```

and a third job:

```yaml
  smoke:
    needs: [lint, test]
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v7
      - name: Build, start and use the whole stack
        run: app/linkly/smoke-test.sh
```

Push, and open the run: lint and the two test jobs run first, then smoke. Its log shows each
`==` section from Module 1 and ends with `SMOKE TEST PASSED`.

## Lab

- [ ] Add the smoke job after lint and test
- [ ] Find the job graph on the run's summary page
- [ ] Push twice quickly and watch the older run get cancelled
- [ ] Break the nginx config on purpose and see only smoke fail

Hint for the nginx break: change `api:8000` to `api:8001` in `app/linkly/web/nginx.container.conf`.
Lint and unit tests still pass; smoke fails at "shorten", and its log shows the 502. Revert it.

## Check yourself

1. Why does smoke wait for lint and test instead of running alongside them?

<details><summary>Answer</summary>

It's the slowest job. If a quick check already failed, starting the whole stack is wasted time,
and the quick failure is easier to read.

</details>

2. What problem does `cancel-in-progress` prevent?

<details><summary>Answer</summary>

Runs for outdated commits on a work branch using up runners. (On `main` runs wait in line
instead, so a half-finished publish can't happen.)

</details>
