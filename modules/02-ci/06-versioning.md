# Versions you can trace

> **You need:** Lesson 5 · **Time:** ~45 min · **Start from:** `checkpoint/02-ci`

## Why this matters

"Something broke in production. Which version is running, and what changed since the last good
one?" If every image is tagged `main` or `latest`, nobody can answer. Good tags tie every image
to a commit, and releases to a version number, and the running app can tell you which one it is.

## Concept

- **Semantic versioning:** `MAJOR.MINOR.PATCH`. Bump PATCH for fixes, MINOR for new features
  that don't break anything, MAJOR for breaking changes.
- **Git tags** mark a release: `v0.2.0` on a commit.
- **The tags our workflow publishes** (from `metadata-action`):

| Pushed | Image tags |
|---|---|
| a commit to `main` | `main`, `sha-<7 chars>` |
| the tag `v0.2.0` | `0.2.0`, `0.2`, `sha-<7 chars>` |

  `sha-` points at the exact commit, forever. `0.2` follows the newest 0.2.x, for people who
  want fixes automatically.
- **Why not `latest`?** It moves silently, so two servers "running latest" can be running
  different code, and a rollback has nothing to roll back *to*.
- **Version at runtime:** the API's Dockerfile takes `ARG VERSION` and sets `LINKLY_VERSION`.
  CI passes the version it worked out, and `/healthz` reports it.

## Example

Locally first:

```bash
docker build --build-arg VERSION=0.2.0 -t linkly-api:0.2.0 app/linkly/api
docker run --rm linkly-api:0.2.0 python -c "import os; print(os.environ['LINKLY_VERSION'])"   # 0.2.0
docker build -t linkly-api:dev app/linkly/api
docker run --rm linkly-api:dev python -c "import os; print(os.environ['LINKLY_VERSION'])"     # dev
```

Then a real release from `main`:

```bash
git switch main && git pull
git tag v0.2.0
git push origin v0.2.0
```

The tag push runs the workflow. When `publish` is done, your packages list `0.2.0`, `0.2` and a
`sha-` tag. Pull and ask it:

```bash
cd app/linkly && docker compose up -d --wait postgres redis     # something for it to talk to
docker run -d --name api-release --network linkly_default -p 8000:8000 \
  -e DATABASE_URL=postgresql://linkly:linkly@postgres:5432/linkly -e REDIS_URL=redis://redis:6379/0 \
  ghcr.io/<you>/linkly-api:0.2.0
sleep 2; curl localhost:8000/healthz                             # {"status":"ok","version":"0.2.0"}
docker rm -f api-release && docker compose down
```

## Lab

- [ ] Tag a release and push the tag
- [ ] List the image tags the release produced
- [ ] Check which version a running container reports
- [ ] Explain when you'd bump major, minor and patch

## Check yourself

1. What are the `sha-` tags for if you also have version numbers?

<details><summary>Answer</summary>

Every build gets one, not just releases, and each points at exactly one commit. You can deploy,
compare or roll back to any build, and always know its source.

</details>

2. Why not deploy `latest`?

<details><summary>Answer</summary>

It changes whenever someone pushes, so you can't tell what's running, two hosts can differ, and
there's no fixed version to go back to.

</details>

3. You fixed a bug without changing any behaviour users rely on. `0.2.0` → ?

<details><summary>Answer</summary>

`0.2.1`: a patch release.

</details>

## Clean up

Delete test tags you don't want: `git push --delete origin v0.2.0 && git tag -d v0.2.0`, and
remove the package versions on GitHub if you like. Nothing here costs money.
