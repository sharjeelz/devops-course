# Your first Dockerfile

> **You need:** Lesson 2 (with `linkly-net`, `postgres` and `redis` still running) · **Time:** ~75 min · **Start from:** `checkpoint/01-containers`

## Why this matters

Postgres and Redis came as ready-made images. Linkly's API is *your* code, so nobody has built
its image yet. A Dockerfile is the recipe: start from a base image, add your code and its
packages, say how to run it. Build once, run the same thing everywhere.

## Concept

The instructions you need for most images:

| Instruction | What it does |
|---|---|
| `FROM` | the base image to start from |
| `WORKDIR` | the folder later instructions run in (created if missing) |
| `COPY` | files from the *build context* (the folder you build from) into the image |
| `RUN` | a command run **while building**, e.g. installing packages |
| `ENV` | an environment variable baked into the image |
| `EXPOSE` | documents which port the program listens on |
| `CMD` | the command run **when a container starts** |

**Layer caching:** each instruction makes a layer, and Docker reuses a layer if nothing it
depends on changed. That's why you copy `requirements.txt` and install packages *before*
copying the code: change one line of code and the slow `pip install` layer is reused.

**`.dockerignore`** keeps files out of the build context (your `.venv`, caches), so builds
are faster and images don't pick up junk.

## Example

In `app/linkly/api`, the repo already has a finished Dockerfile (lesson 4). Put it aside and
write the simplest one that works. Save this as `Dockerfile.simple`:

```dockerfile
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY linkly_api ./linkly_api
EXPOSE 8000
CMD ["uvicorn", "linkly_api.main:app_from_env", "--factory", "--host", "0.0.0.0", "--port", "8000"]
```

`--host 0.0.0.0` matters: by default uvicorn listens on `127.0.0.1`, which inside a container
means "only this container" (Module 0, lesson 2), and `-p` could never reach it.

```bash
cd app/linkly/api
docker build -f Dockerfile.simple -t linkly-api:simple .
docker run -d --name api --network linkly-net -p 8000:8000 \
  -e DATABASE_URL=postgresql://linkly:linkly@postgres:5432/linkly \
  -e REDIS_URL=redis://redis:6379/0 \
  linkly-api:simple
curl localhost:8000/healthz                             # {"status":"ok"}
curl -s -X POST localhost:8000/api/links -H 'content-type: application/json' -d '{"url":"https://example.com"}'
```

Now change one line in `linkly_api/main.py` (say, the `title="Linkly"`) and build again: watch
the output say `CACHED` for the `pip install` step.

## Lab

- [ ] Write a single-stage Dockerfile for the API and build it
- [ ] Run the API container against the Postgres and Redis containers by name
- [ ] Shorten a link with curl against the containerised API
- [ ] Change one line of code and see which layers rebuild
- [ ] Add a .dockerignore and compare the build context size

Hint: the build output's first lines show "transferring context: …". The repo already has a
`.dockerignore`: rename it away (`mv .dockerignore /tmp/`), build with your `.venv` in the
folder, then put it back and build again. The number drops a lot.

## Check yourself

1. Why copy `requirements.txt` before the rest of the code?

<details><summary>Answer</summary>

So the slow package-install layer only rebuilds when the requirements change. Code changes
then only rebuild the cheap last layer.

</details>

2. What's the difference between `RUN` and `CMD`?

<details><summary>Answer</summary>

`RUN` executes while the image is being built and its result is saved in a layer. `CMD` is
what runs each time a container starts from the image.

</details>

3. The container is running but `curl localhost:8000` gets "connection reset". What's the likely cause?

<details><summary>Answer</summary>

The program inside is listening on `127.0.0.1`, so only the container itself can reach it.
Listen on `0.0.0.0`.

</details>

## Clean up

`docker rm -f api`. Keep `linkly-api:simple` to compare sizes in lesson 4, and keep the network,
`postgres` and `redis`.
