# Small, safe images

> **You need:** Lesson 3 · **Time:** ~60 min · **Start from:** `checkpoint/01-containers`

## Why this matters

Your lesson-3 image works, but run `docker run --rm linkly-api:simple id -u` and it prints `0`:
it runs as **root**. If someone finds a bug in your API, they're root inside the container,
one step closer to the host. It also carries everything used to build it, and the tests run
somewhere else, on whatever Python your machine has. Production images should be small,
non-root, and tested in the same environment they ship in.

## Concept

- **Multi-stage builds:** one Dockerfile, several `FROM` stages. Later stages copy only what
  they need from earlier ones (`COPY --from=deps ...`), so build tools and test packages never
  reach the final image.
- **A `test` stage:** the same base and packages as production, plus the test tools.
  `docker build --target test` builds just that stage. From Module 2, CI runs it.
- **Non-root `USER`:** create a system user and switch to it before `CMD`.
- **`HEALTHCHECK`:** a command Docker runs regularly to ask "are you actually working?", so
  "running" and "healthy" stop being the same thing.
- **Pinned tags:** `python:3.12-slim`, not `python:latest`. `latest` changes under you, and a
  build that worked yesterday breaks today.

## Example

Open the repo's real `app/linkly/api/Dockerfile`. It has four stages:

1. `base`: Python 3.12 slim, with settings that stop Python writing cache files.
2. `deps`: installs `requirements.txt` into `/install`.
3. `test`: copies those packages, adds the test tools and the tests, and runs pytest.
4. `runtime`: copies the packages and the code only, creates user `linkly` (uid 10001), switches to it, adds a HEALTHCHECK.

```bash
cd app/linkly/api
docker build --target test -t linkly-api:test . && docker run --rm linkly-api:test   # 15 passed
docker build -t linkly-api .                                                         # the last stage is the default
docker run --rm linkly-api id -u                                                     # 10001
docker image ls linkly-api
```

Measured on the author's machine:

| Image | Size | Runs as |
|---|---|---|
| `linkly-api:simple` (lesson 3) | ~323 MB | root (0) |
| `linkly-api` (multi-stage runtime) | ~270 MB | linkly (10001) |
| `linkly-api:test` | ~295 MB | root, but it never ships |

Most of what's left is Python itself and the packages Linkly needs (~73 MB). The win is
less about megabytes and more about what *isn't* there: no pip cache, no tests, no root.

The worker's Dockerfile (`app/linkly/worker/Dockerfile`) has exactly the same shape.

## Lab

- [ ] Build the API's test stage and run the tests inside it
- [ ] Prove the runtime image runs as a non-root user
- [ ] Compare your lesson-3 image size with the multi-stage one
- [ ] Build the worker image and run its tests the same way
- [ ] Explain what the HEALTHCHECK line adds

Hint: after starting a container from `linkly-api`, `docker ps` shows `(health: starting)`
and then `(healthy)` in the STATUS column.

## Check yourself

1. In a multi-stage build, what from the earlier stages ends up in the final image?

<details><summary>Answer</summary>

Only what the final stage explicitly copies with `COPY --from=...`. Everything else in the
earlier stages is left behind.

</details>

2. Why bother with a non-root user if the app is in a container anyway?

<details><summary>Answer</summary>

Defence in depth: a container is isolation, not a guarantee. If an attacker gets code
execution, being root inside makes escaping or damaging mounted data far easier.

</details>

3. Why not `FROM python:latest`?

<details><summary>Answer</summary>

`latest` moves: a new major Python could arrive tomorrow and break your build or your app
with no change on your side. A pinned tag makes builds repeatable.

</details>

## Clean up

`docker image rm linkly-api:simple` once you've compared sizes.
