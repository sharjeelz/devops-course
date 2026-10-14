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

To run it by hand on Linux, see [Module 0, lesson 4](../../modules/00-foundations/04-run-linkly-by-hand.md).
Module 1 turns all of that into one command.
