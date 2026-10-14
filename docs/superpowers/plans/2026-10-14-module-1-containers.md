# Module 1 (Containers) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Module 1 turns Module 0's page of manual steps into one command. It covers:
- a container image for each Linkly service (api, worker, web)
- a Compose file for the whole stack
- a smoke test that proves the stack works end to end
- seven lessons that teach it in order

**Architecture:**
- **Images:**
  - `api` and `worker` use multi-stage Python images: a `test` stage that runs pytest, and a small non-root runtime stage.
  - `web` is nginx serving the static page, with a container-specific config whose upstream is `api:8000`. Module 0's by-hand `nginx.conf` stays as it is.
- **Compose:** `app/linkly/compose.yaml` wires postgres and redis (with healthchecks and a named volume for data) to api, worker and web on one network, published on `${LINKLY_PORT:-8080}`.
- **Smoke test:** `app/linkly/smoke-test.sh` builds and starts the stack, exercises it through nginx, and tears it down. Module 2's CI will reuse it.

**Tech Stack:** Docker Engine 25+ with Compose v2, python:3.12-slim, nginx:1.27-alpine, postgres:16-alpine, redis:7-alpine, bash + curl.

**Spec:** `docs/superpowers/specs/2026-10-14-course-design.md` (module map row 1: "Dockerfile per service, multi-stage builds, Compose for the whole stack, volumes; landscape: Podman, containerd").

## Global Constraints

- Lesson format is unchanged from Module 0:
  - file names follow `NN-slug`
  - the first line is `# Title`
  - sections run Why this matters → Concept → Example → Lab (unique `- [ ]` items) → Check yourself (`<details>` answers) → optional Stretch / Clean up
  - every lesson header line names `**Start from:** \`checkpoint/01-containers\``
- Module 0 keeps working: `app/linkly/web/nginx.conf` and Module 0's lessons are not changed.
- Images run as a non-root user and contain no tests, venvs or caches (enforced by `.dockerignore` and the runtime stage).
- One command brings everything up: `docker compose up -d --build --wait` from `app/linkly`.
- Nothing in this module costs money. The clean-up is `docker compose down` (keep data) or `down -v` (delete data).
- Image tags are pinned to a minor version (e.g. `postgres:16-alpine`, `python:3.12-slim`), never `latest`.
- Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **The worker starts before the API has created the `links` table.** Its UPDATE fails; the clicks must go back on the queue and be counted once the table exists (already handled by `step()`). Compose `depends_on: api: service_healthy` makes the race rare. Pinned in Task 3: the smoke test clicks right after `--wait`.
2. **The data volume survives `docker compose down`** and disappears with `down -v`. Pinned in Task 3 (smoke test, restart phase).
3. **Port 8080 is already taken on a learner's machine.** `LINKLY_PORT` overrides it, and the lesson says so. Pinned in Task 3 (the smoke test honours `LINKLY_PORT`).
4. **Containers run as root.** The runtime images must not. Pinned in Task 2 (the smoke test checks `id -u` ≠ 0 in api and worker).
5. **Windows line endings in shell scripts copied into images or run in WSL.** `.gitattributes` already forces LF; the smoke test must run from Git Bash and WSL alike. Pinned in Task 3 (run from Git Bash on Windows).

---

## File Structure

```
app/linkly/
  compose.yaml                 the whole stack
  smoke-test.sh                build, start, exercise through nginx, restart with data kept, tear down
  api/Dockerfile, api/.dockerignore
  worker/Dockerfile, worker/.dockerignore
  web/Dockerfile, web/nginx.container.conf
modules/01-containers/
  README.md
  01-why-containers.md
  02-networks-and-volumes.md
  03-your-first-dockerfile.md
  04-small-safe-images.md
  05-web-in-a-container.md
  06-compose.md
  07-landscape.md
```

---

### Task 1: The smoke test (written first, fails)

**Files:**
- Create: `app/linkly/smoke-test.sh`

**Interfaces:**
- Consumes: the compose service names (`postgres`, `redis`, `api`, `worker`, `web`), `LINKLY_PORT`, the HTTP API.
- Produces: `./smoke-test.sh` exits 0 and prints `SMOKE TEST PASSED` only when the whole stack works.

- [ ] **Step 1: Write the script**

`app/linkly/smoke-test.sh`:

```bash
#!/usr/bin/env bash
# Builds and starts Linkly with Docker Compose, uses it through nginx like a person would,
# restarts it to prove the data survives, then removes everything it created.
# Usage: ./smoke-test.sh            (LINKLY_PORT=9090 ./smoke-test.sh if 8080 is taken)
set -euo pipefail
cd "$(dirname "$0")"
export LINKLY_PORT="${LINKLY_PORT:-8080}"
export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-linkly-smoke}"
base="http://localhost:${LINKLY_PORT}"

fail() { echo "SMOKE TEST FAILED: $*" >&2; docker compose logs --tail 30 >&2 || true; exit 1; }
cleanup() { docker compose down -v --remove-orphans >/dev/null 2>&1 || true; }
trap cleanup EXIT

echo "== build and start"
docker compose up -d --build --wait || fail "stack did not become healthy"

echo "== images don't run as root"
for svc in api worker; do
  uid=$(docker compose exec -T "$svc" id -u) || fail "$svc: can't run id"
  [ "$uid" != "0" ] || fail "$svc runs as root"
done

echo "== the page is served"
curl -fsS "$base/" | grep -q "<title>Linkly</title>" || fail "page not served at $base/"

echo "== shorten, redirect, count"
body=$(curl -fsS -X POST "$base/api/links" -H 'content-type: application/json' -d '{"url":"https://example.com/smoke"}') || fail "shorten failed"
code=$(echo "$body" | sed -E 's/.*"code":"([^"]+)".*/\1/')
[ ${#code} -eq 7 ] || fail "no code in: $body"
read -r status target < <(curl -s -o /dev/null -w '%{http_code} %{redirect_url}\n' "$base/r/$code")
[ "$status" = "307" ] && [ "$target" = "https://example.com/smoke" ] || fail "redirect gave $status $target"
curl -s -o /dev/null "$base/r/$code"
clicks=0
for _ in $(seq 1 20); do
  clicks=$(curl -fsS "$base/api/links/$code" | sed -E 's/.*"clicks":([0-9]+).*/\1/')
  [ "$clicks" -ge 2 ] && break
  sleep 1
done
[ "$clicks" -eq 2 ] || fail "expected 2 clicks, got $clicks"

echo "== bad input is refused"
[ "$(curl -s -o /dev/null -w '%{http_code}' -X POST "$base/api/links" -H 'content-type: application/json' -d '{"url":"javascript:alert(1)"}')" = "422" ] || fail "javascript: URL not refused"

echo "== data survives a restart (down without -v)"
docker compose down >/dev/null 2>&1 || fail "down failed"
docker compose up -d --wait >/dev/null 2>&1 || fail "restart failed"
[ "$(curl -s -o /dev/null -w '%{http_code}' "$base/r/$code")" = "307" ] || fail "link lost after restart"

echo "SMOKE TEST PASSED"
```

- [ ] **Step 2: Run it to verify it fails**

Run (Git Bash, from `app/linkly`): `chmod +x smoke-test.sh && ./smoke-test.sh`
Expected: `SMOKE TEST FAILED: stack did not become healthy`, because there is no `compose.yaml` yet ("no configuration file provided").

- [ ] **Step 3: Commit**

```bash
git add app/linkly/smoke-test.sh
git commit -m "test(linkly): smoke test for the containerised stack (fails until Compose exists)"
```

---

### Task 2: Images for api, worker and web

**Files:**
- Create: `app/linkly/api/Dockerfile`, `app/linkly/api/.dockerignore`, `app/linkly/worker/Dockerfile`, `app/linkly/worker/.dockerignore`, `app/linkly/web/Dockerfile`, `app/linkly/web/nginx.container.conf`

**Interfaces:**
- Produces:
  - Image targets `test` and the default runtime target for api and worker.
  - The api runtime listens on `0.0.0.0:8000`, has a HEALTHCHECK on `/healthz`, and runs as uid 10001.
  - The worker runtime runs `python -m linkly_worker.main` as uid 10001.
  - The web image serves on 8080 and proxies `/api/` and `/r/` to `api:8000`.

- [ ] **Step 1: Write the images**

`app/linkly/api/.dockerignore` (and the same content for `app/linkly/worker/.dockerignore`):

```
.venv/
**/__pycache__/
.pytest_cache/
*.pyc
Dockerfile
.dockerignore
```

`app/linkly/api/Dockerfile`:

```dockerfile
# syntax=docker/dockerfile:1
# Linkly API. Stages: deps (install packages) → test (run the tests) → runtime (what ships).
#   docker build -t linkly-api .                 # the runtime image
#   docker build --target test -t linkly-api:test . && docker run --rm linkly-api:test
FROM python:3.12-slim AS base
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1 PIP_DISABLE_PIP_VERSION_CHECK=1
WORKDIR /app

FROM base AS deps
COPY requirements.txt .
RUN pip install --prefix=/install -r requirements.txt

FROM base AS test
COPY --from=deps /install /usr/local
COPY requirements-dev.txt requirements.txt pytest.ini ./
RUN pip install -r requirements-dev.txt
COPY linkly_api ./linkly_api
COPY tests ./tests
CMD ["python", "-m", "pytest", "-q"]

FROM base AS runtime
COPY --from=deps /install /usr/local
COPY linkly_api ./linkly_api
RUN useradd --system --uid 10001 --no-create-home linkly
USER linkly
EXPOSE 8000
HEALTHCHECK --interval=5s --timeout=3s --start-period=5s --retries=5 \
  CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/healthz', timeout=2)"]
CMD ["uvicorn", "linkly_api.main:app_from_env", "--factory", "--host", "0.0.0.0", "--port", "8000"]
```

`app/linkly/worker/Dockerfile`:

```dockerfile
# syntax=docker/dockerfile:1
# Linkly worker. Same shape as the API image: deps → test → runtime.
FROM python:3.12-slim AS base
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1 PIP_DISABLE_PIP_VERSION_CHECK=1
WORKDIR /app

FROM base AS deps
COPY requirements.txt .
RUN pip install --prefix=/install -r requirements.txt

FROM base AS test
COPY --from=deps /install /usr/local
COPY requirements-dev.txt requirements.txt pytest.ini ./
RUN pip install -r requirements-dev.txt
COPY linkly_worker ./linkly_worker
COPY tests ./tests
CMD ["python", "-m", "pytest", "-q"]

FROM base AS runtime
COPY --from=deps /install /usr/local
COPY linkly_worker ./linkly_worker
RUN useradd --system --uid 10001 --no-create-home linkly
USER linkly
CMD ["python", "-m", "linkly_worker.main"]
```

`app/linkly/web/nginx.container.conf`:

```nginx
# Linkly's front door inside a container. Same as nginx.conf (Module 0), except that the API is
# no longer on this machine's 127.0.0.1: it's another container, found by its service name.
server {
    listen 8080;
    root /usr/share/nginx/html;
    index index.html;

    location /api/ { proxy_pass http://api:8000; proxy_set_header Host $host; proxy_set_header X-Forwarded-For $remote_addr; }
    location /r/   { proxy_pass http://api:8000; proxy_set_header Host $host; proxy_set_header X-Forwarded-For $remote_addr; }
    location /     { try_files $uri $uri/ =404; }
}
```

`app/linkly/web/Dockerfile`:

```dockerfile
# Linkly web: nginx serving the page and forwarding /api/ and /r/ to the api container.
FROM nginx:1.27-alpine
COPY nginx.container.conf /etc/nginx/conf.d/default.conf
COPY index.html app.js style.css /usr/share/nginx/html/
EXPOSE 8080
```

- [ ] **Step 2: Verify each image**

Run (from `app/linkly`):

```bash
docker build --target test -t linkly-api:test api && docker run --rm linkly-api:test
docker build --target test -t linkly-worker:test worker && docker run --rm linkly-worker:test
docker build -t linkly-api api && docker run --rm linkly-api id -u
docker build -t linkly-worker worker && docker run --rm linkly-worker id -u
docker build -t linkly-web web && docker run --rm --add-host api:127.0.0.1 linkly-web nginx -t
docker image ls --format '{{.Repository}}:{{.Tag}} {{.Size}}' | grep '^linkly-'
```

Expected:
- `15 passed` and `5 passed` from the test images.
- `10001` twice.
- nginx reports `syntax is ok` and `test is successful`.
- Runtime images are well under 250 MB, and the web image is under 80 MB.

- [ ] **Step 3: Commit**

```bash
git add app/linkly/api/Dockerfile app/linkly/api/.dockerignore app/linkly/worker/Dockerfile app/linkly/worker/.dockerignore app/linkly/web/Dockerfile app/linkly/web/nginx.container.conf
git commit -m "feat(linkly): container images - multi-stage api/worker with a test stage, non-root; nginx web image"
```

---

### Task 3: Compose for the whole stack

**Files:**
- Create: `app/linkly/compose.yaml`
- Modify: `app/linkly/README.md` (add "Run it with Docker")

**Interfaces:**
- Consumes: the images from Task 2 and the smoke test from Task 1.
- Produces: `docker compose up -d --build --wait` brings up a healthy stack on `${LINKLY_PORT:-8080}`.

- [ ] **Step 1: Write the Compose file**

`app/linkly/compose.yaml`:

```yaml
# Linkly, all five parts, one command:   docker compose up -d --build --wait
# Then open http://localhost:8080  (LINKLY_PORT=9090 docker compose up ... if 8080 is taken)
name: linkly

x-app-env: &app-env
  DATABASE_URL: postgresql://linkly:linkly@postgres:5432/linkly
  REDIS_URL: redis://redis:6379/0

services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: linkly
      POSTGRES_PASSWORD: linkly
      POSTGRES_DB: linkly
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U linkly -d linkly"]
      interval: 2s
      timeout: 3s
      retries: 30
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 2s
      timeout: 3s
      retries: 30
    restart: unless-stopped

  api:
    build: ./api
    environment:
      <<: *app-env
      BASE_URL: http://localhost:${LINKLY_PORT:-8080}
    depends_on:
      postgres: { condition: service_healthy }
      redis: { condition: service_healthy }
    restart: unless-stopped

  worker:
    build: ./worker
    environment: *app-env
    depends_on:
      api: { condition: service_healthy }
    restart: unless-stopped

  web:
    build: ./web
    ports:
      - "${LINKLY_PORT:-8080}:8080"
    depends_on:
      api: { condition: service_healthy }
    healthcheck:
      test: ["CMD", "wget", "-q", "-O", "/dev/null", "http://127.0.0.1:8080/"]
      interval: 2s
      timeout: 3s
      retries: 30
    restart: unless-stopped

volumes:
  pgdata:
```

Note: the `worker` has no healthcheck, so `--wait` treats "running" as ready. `--wait` covers every service.

- [ ] **Step 2: Run the smoke test**

Run (Git Bash, from `app/linkly`): `./smoke-test.sh`
Expected: each `==` section prints, then `SMOKE TEST PASSED`; `docker ps` afterwards shows no `linkly-smoke` containers.

- [ ] **Step 3: Add "Run it with Docker" to `app/linkly/README.md`**

Replace the "## Running it" section with:

```markdown
## Running it

With Docker (Module 1 onwards), from this folder:

    docker compose up -d --build --wait      # build and start all five parts
    open http://localhost:8080               # LINKLY_PORT=9090 docker compose up ... if 8080 is taken
    docker compose logs -f worker            # watch clicks being counted
    docker compose down                      # stop (data kept in the pgdata volume)
    docker compose down -v                   # stop and delete the data

`./smoke-test.sh` builds, starts, exercises and removes a throwaway copy of the stack.

By hand on Linux (Module 0): see [Module 0, lesson 4](../../modules/00-foundations/04-run-linkly-by-hand.md).
```

- [ ] **Step 4: Commit**

```bash
git add app/linkly/compose.yaml app/linkly/README.md
git commit -m "feat(linkly): Compose for the whole stack - healthchecks, startup order, data volume, one command"
```

---

### Task 4: Module 1 lessons

**Files:**
- Create: `modules/01-containers/README.md` and the seven lessons.

**Interfaces:**
- Consumes: the files from Tasks 1–3. Lesson commands must match them exactly: service names, ports, targets, uid.
- Produces: lessons the JARVIS Course tab reads.

Every lesson follows the template. The required content for each is below; examples use the real files.

- [ ] **Step 1: `README.md`, "# Containers (Docker)"**
  - Header: You need Module 0 · Time ~8 h · Start from `checkpoint/01-containers`.
  - What you'll build: the Module 0 list of manual steps becomes `docker compose up`.
  - Install Docker:
    - **Windows:** Docker Desktop with "Use the WSL 2 based engine" on, plus WSL integration enabled for Ubuntu.
    - **Linux or a VM:** `sudo apt install -y docker.io docker-compose-v2 && sudo usermod -aG docker $USER`, then log out and back in.
  - Check the install: `docker run --rm hello-world`.
  - The lesson list, one line each.
  - "By the end, `checkpoint/02-ci` holds Linkly with these files."

- [ ] **Step 2: `01-why-containers.md`, "# Why containers"**
  - **Why:** recall Module 0's list (versions, order, "works on my machine").
  - **Concept:**
    - image vs container (a class vs its instances)
    - layers, registries and tags
    - containers vs VMs (shared kernel, namespaces and cgroups, in one paragraph)
  - **Example:** `docker run -d --name redis-try -p 6379:6379 redis:7-alpine`, `docker ps`, `docker exec -it redis-try redis-cli ping`, `docker logs`, `docker stop`/`rm`, then `docker run --rm -it postgres:16-alpine psql --version`.
  - **Lab:**
    - Run Redis in a container and ping it
    - Find the image's size and layers with `docker image history`
    - Run two different Postgres versions side by side on different host ports
    - Stop the apt-installed Redis from Module 0 and use the container instead
    - Explain why the two Postgres versions didn't conflict
  - **Check yourself:** image vs container; what `-p 8080:80` means; why a container starts in milliseconds and a VM doesn't; what happens to files written inside a container when it's removed.

- [ ] **Step 3: `02-networks-and-volumes.md`, "# Networks and volumes"**
  - **Why:** containers must find each other, and data must outlive them.
  - **Concept:**
    - a user-defined bridge network gives DNS by container name
    - `localhost` inside a container is the container itself
    - named volumes vs bind mounts
  - **Example:**
    - `docker network create linkly-net`
    - `docker run -d --name postgres --network linkly-net -e POSTGRES_USER=linkly -e POSTGRES_PASSWORD=linkly -e POSTGRES_DB=linkly -v linkly-pg:/var/lib/postgresql/data postgres:16-alpine`
    - `docker run --rm --network linkly-net postgres:16-alpine pg_isready -h postgres`
    - then remove and recreate the container and show the data is still there (`psql` creates a table first)
  - **Lab:**
    - Create a network and reach one container from another by name
    - Show that `localhost` inside a container does not reach the other container
    - Put Postgres data on a named volume, delete the container, and get the data back
    - Use a bind mount to serve a folder from your machine with `nginx:1.27-alpine`
    - List and remove the volumes you created
  - **Check yourself:** why `localhost` fails between containers; volume vs bind mount; what `docker volume prune` would delete.
  - **Clean up:** remove the containers, the network and the volume.

- [ ] **Step 4: `03-your-first-dockerfile.md`, "# Your first Dockerfile"**
  - **Why:** you need *your* app as an image.
  - **Concept:**
    - instructions (FROM, WORKDIR, COPY, RUN, ENV, EXPOSE, CMD)
    - layer caching: why `requirements.txt` is copied before the code
    - build context and `.dockerignore`
  - **Example:**
    - Write a deliberately simple single-stage Dockerfile for the API (python:3.12-slim, copy, pip install, uvicorn on `0.0.0.0`). Explain why `--host 0.0.0.0`, tying back to Module 0 lesson 2.
    - Build it.
    - Run it on `linkly-net` with `-e DATABASE_URL=postgresql://linkly:linkly@postgres:5432/linkly -e REDIS_URL=redis://redis:6379/0 -p 8000:8000`.
    - `curl localhost:8000/healthz`.
    - Edit a line of code and rebuild to watch the cache.
  - **Lab:**
    - Write a single-stage Dockerfile for the API and build it
    - Run the API container against the Postgres and Redis containers by name
    - Shorten a link with curl against the containerised API
    - Change one line of code and see which layers rebuild
    - Add a .dockerignore and compare the build context size
  - **Check yourself:** why copy requirements first; what `--host 0.0.0.0` changes; CMD vs RUN.

- [ ] **Step 5: `04-small-safe-images.md`, "# Small, safe images"**
  - **Why:** big images are slow to ship, root containers are a risk, and tests should run in the same environment.
  - **Concept:**
    - multi-stage builds
    - a `test` target
    - non-root `USER`
    - HEALTHCHECK
    - pinned tags vs `latest`
  - **Example:**
    - Walk through the repo's real `api/Dockerfile` stage by stage.
    - `docker build --target test -t linkly-api:test app/linkly/api && docker run --rm linkly-api:test`
    - `docker run --rm linkly-api id -u` gives 10001.
    - Compare sizes with the lesson 3 image.
    - Then the worker image, which has the same shape.
  - **Lab:**
    - Build the API's test stage and run the tests inside it
    - Prove the runtime image runs as a non-root user
    - Compare your lesson-3 image size with the multi-stage one
    - Build the worker image and run its tests the same way
    - Explain what the HEALTHCHECK line adds
  - **Check yourself:** what ends up in the final image from earlier stages; why non-root; why not `latest`.

- [ ] **Step 6: `05-web-in-a-container.md`, "# The web front door in a container"**
  - **Why:** nginx was the last hand-configured piece.
  - **Concept:** `nginx.container.conf` vs Module 0's `nginx.conf`, a one-line diff (`127.0.0.1:8000` becomes `api:8000`) and why. Plus the official nginx image's conf.d.
  - **Example:**
    - `docker build -t linkly-web app/linkly/web`
    - `docker run --rm --add-host api:127.0.0.1 linkly-web nginx -t`
    - Run all five containers by hand on `linkly-net`, with web on `-p 8080:8080` and the API container named `api`.
    - Use the page.
  - **Lab:**
    - Build the web image and check its nginx config
    - Run all five Linkly containers by hand on one network
    - Shorten and click a link through the containerised page
    - Count the docker run flags you needed and write them down
  - **Check yourself:** why `127.0.0.1:8000` breaks inside the web container; what 502 now means.
  - **Clean up:** remove all five containers (the network and volume stay for lesson 6).

- [ ] **Step 7: `06-compose.md`, "# One command: Docker Compose"**
  - **Why:** lesson 5's pile of flags is Module 0's list again.
  - **Concept:**
    - services, networks and volumes declared once
    - `depends_on` with `condition: service_healthy`
    - restart policies
    - `${LINKLY_PORT:-8080}`
    - the YAML anchor for shared env
  - **Example:**
    - Walk through `compose.yaml`.
    - `cd app/linkly && docker compose up -d --build --wait`, `docker compose ps`, `docker compose logs -f worker`.
    - Then `docker compose down` and `up` again: the links are still there.
    - Then `./smoke-test.sh`.
    - Note: if 8080 is taken, use `LINKLY_PORT=9090`.
  - **Lab:**
    - Start the whole stack with one command
    - Watch the worker's log while clicking a link
    - Stop Postgres with docker compose stop and watch the worker wait instead of crashing
    - Restart the stack and show your links survived
    - Run the smoke test and read what each section checks
    - Compare this with your Module 0 list of manual steps
  - **Check yourself:** what `--wait` waits for; `down` vs `down -v`; why the worker waits for the api's health.
  - **Clean up:** `docker compose down -v`.

- [ ] **Step 8: `07-landscape.md`, "# Landscape: beyond Docker"**
  - **Why:** "Docker" means several things, and production clusters mostly don't run Docker Engine.
  - **Concept:**
    - OCI images and runtimes
    - containerd and runc under Docker
    - Kubernetes uses containerd/CRI-O directly (dockershim was removed in 1.24)
    - Podman (daemonless, rootless, `podman compose`)
    - BuildKit and buildx (multi-arch)
    - Docker Desktop licensing for large companies, in one neutral sentence
    - short history: LXC → Docker (2013) → OCI (2015) → containerd donated to CNCF
  - **Example:**
    - `docker info | grep -iE "runtime|containerd"`
    - `docker buildx ls`
    - optional: `sudo apt install -y podman` and `podman run --rm docker.io/library/redis:7-alpine redis-server --version`
  - **Lab:**
    - Find which runtime your Docker Engine uses
    - Explain what an OCI image is in two sentences
    - Run one Linkly image with Podman (optional)
    - Name one reason a team might pick Podman over Docker
  - **Check yourself:** did Kubernetes "drop Docker images"? (no, only dockershim; images are OCI); containerd vs runc.

- [ ] **Step 9: Verify the format**

Run the Module 0 format check against `modules/01-containers` (same rules; every lesson has all five required sections). Then check the live Course tab API lists "Containers (Docker)" with an overview and 7 lessons.

- [ ] **Step 10: Commit**

```bash
git add modules/01-containers
git commit -m "docs(module-1): Containers - why containers, networks & volumes, Dockerfiles, small safe images, web, Compose, landscape"
```

---

### Task 5: Checkpoint for Module 2

- [ ] **Step 1:** `git branch checkpoint/02-ci HEAD` (Linkly with Dockerfiles and Compose, as it stands at the start of Module 2). Check with `git ls-tree -r --name-only checkpoint/02-ci | grep -c Dockerfile`, which should print `3`.
- [ ] **Step 2:** In `README.md` "How to start", change the checkpoint sentence to also name `checkpoint/02-ci` as "Linkly at the end of Module 1". Commit `docs: checkpoint branch for module 2`.
