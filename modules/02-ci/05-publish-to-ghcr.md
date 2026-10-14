# Publishing images to GHCR

> **You need:** Lesson 4 · **Time:** ~60 min · **Start from:** `checkpoint/02-ci`

## Why this matters

So far the images CI builds are thrown away with the runner. To run Linkly anywhere else (a
server, a Kubernetes cluster in Module 3), the tested images need to live in a **registry**,
where any machine can pull exactly what CI checked.

## Concept

- **GHCR (GitHub Container Registry):** a registry at `ghcr.io`, with images named
  `ghcr.io/<owner>/<image>:<tag>`. It's free for public images and tied to your GitHub account.
- **`GITHUB_TOKEN`:** a token GitHub creates for every run and revokes when it ends. What it
  may do is set by `permissions:`.
- **Least privilege:** the workflow's default stays `contents: read`; only the `publish` job
  gets `packages: write`. A compromised lint step can't push images.
- **Never publish from pull requests.** Anyone can open a PR against a public repo; their code
  must not be able to push your images. Publishing runs only on `push` (to `main` or a tag),
  and GitHub doesn't give pull requests from forks a write token anyway.
- **Registry names are lowercase.** A fork owned by `SharjeelZ` must push to `ghcr.io/sharjeelz/...`.

## Example

Add to `on:` so the workflow also runs for version tags (lesson 6):

```yaml
on:
  push:
    branches: [main]
    tags: ["v*"]
  pull_request:
```

and the fourth job:

```yaml
  publish:
    needs: smoke
    if: github.event_name == 'push'
    runs-on: ubuntu-24.04
    permissions:
      contents: read
      packages: write
    strategy:
      matrix:
        service: [api, worker, web]
    steps:
      - uses: actions/checkout@v7
      - name: Image name (registry names must be lowercase)
        run: echo "IMAGE=ghcr.io/${GITHUB_REPOSITORY_OWNER,,}/linkly-${{ matrix.service }}" >> "$GITHUB_ENV"
      - uses: docker/setup-buildx-action@v4
      - uses: docker/login-action@v4
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - id: meta
        uses: docker/metadata-action@v6
        with:
          images: ${{ env.IMAGE }}
          tags: |
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=sha
            type=raw,value=main,enable={{is_default_branch}}
      - uses: docker/build-push-action@v7
        with:
          context: app/linkly/${{ matrix.service }}
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          build-args: VERSION=${{ steps.meta.outputs.version }}
          cache-from: type=gha,scope=${{ matrix.service }}
          cache-to: type=gha,mode=max,scope=${{ matrix.service }}
```

`${GITHUB_REPOSITORY_OWNER,,}` is bash for "lowercased". The `meta` step works out the tags;
lesson 6 explains them.

Merge your branch into `main` in your fork (through a pull request, so your required checks
run). The push to `main` runs all four jobs; `publish` pushes three images. Find them on your
GitHub profile under **Packages**. New packages are private; to pull one without logging in,
open its **Package settings** and change the visibility to public. Then:

```bash
docker pull ghcr.io/<you>/linkly-api:main
docker image ls ghcr.io/<you>/linkly-api
```

## Lab

- [ ] Add the publish job
- [ ] Find your three images under your GitHub packages
- [ ] Pull your API image on your machine
- [ ] Open a pull request and confirm nothing was published
- [ ] Explain why the owner is lowercased

## Check yourself

1. What does the `permissions:` block on the publish job change?

<details><summary>Answer</summary>

It gives that job's `GITHUB_TOKEN` permission to write packages. Every other job keeps the
workflow default, read-only repository contents, so they can't push images.

</details>

2. Why doesn't a pull request publish images?

<details><summary>Answer</summary>

PR code hasn't been reviewed or merged yet, and on a public repo anyone can open one. The job
only runs on `push`, and GitHub gives fork PRs a read-only token as a second safety net.

</details>

3. GHCR or Docker Hub: what's the practical difference for this course?

<details><summary>Answer</summary>

Both are registries. GHCR uses the same GitHub account and the automatic `GITHUB_TOKEN`, so
there's no extra account or secret to manage. Docker Hub would need its own login token
stored as a repository secret.

</details>
