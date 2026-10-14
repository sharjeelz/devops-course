# Linkly

A small URL shortener: paste a long link, get a short one, see how often it's clicked. It's the
app you'll grow through the whole course, so it's deliberately small but has the parts real
systems have: a web front end, an API, a database, a cache, a queue and a background worker.

```
browser → nginx :8080 ─┬─ static files (web/)
                       └─ /api/, /r/ → api :8000 ─┬─ postgres (links, click counts)
                                                  └─ redis (cache, "clicks" queue) ← worker → postgres
```

| Part | What it does | Code |
|---|---|---|
| `web` | The page you use. Plain HTML and JavaScript, served by nginx, which also forwards `/api/` and `/r/` to the API. | [`web/`](web/) |
| `api` | Python FastAPI. Creates short links, redirects `/r/<code>` (cached in Redis), queues a click per redirect, serves stats. | [`api/`](api/) |
| `worker` | Takes queued clicks off Redis in batches and adds them to the counts in Postgres. | [`worker/`](worker/) |
| `postgres` | Stores links and their click counts (table `links`, created by the API on start). | — |
| `redis` | Cache for redirects (`link:<code>`, 1 hour) and the `clicks` queue. | — |

## Configuration

Everything comes from environment variables:

| Variable | Used by | Default |
|---|---|---|
| `DATABASE_URL` | api, worker | required, e.g. `postgresql://linkly:linkly@localhost:5432/linkly` |
| `REDIS_URL` | api, worker | `redis://localhost:6379/0` |
| `BASE_URL` | api | `http://localhost:8080` (used to build short links) |

## Running the tests

```bash
cd app/linkly/api && python3 -m venv .venv && .venv/bin/pip install -r requirements-dev.txt && .venv/bin/python -m pytest -q
cd ../worker && python3 -m venv .venv && .venv/bin/pip install -r requirements-dev.txt && .venv/bin/python -m pytest -q
```

The tests need no database: they use an in-memory store and a fake Redis. Set
`LINKLY_TEST_DATABASE_URL` to also test against a real Postgres.

## Running it

With Docker (Module 1 onwards), from this folder:

```bash
docker compose up -d --build --wait      # build and start all five parts, wait until healthy
# open http://localhost:8080             # 8080 taken? echo LINKLY_PORT=9090 > .env  (applies to every command)
docker compose logs -f worker            # watch clicks being counted
docker compose down                      # stop (data kept in the pgdata volume)
docker compose down -v                   # stop and delete the data
```

`./smoke-test.sh` builds, starts, exercises and removes a throwaway copy of the stack.

Each Python image also has a `test` stage: `docker build --target test -t linkly-api:test api && docker run --rm linkly-api:test`.

By hand on Linux (Module 0): see [Module 0, lesson 4](../../modules/00-foundations/04-run-linkly-by-hand.md).
