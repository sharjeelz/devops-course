# Linkly v0 and Module 0 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The course repo's foundation: the course README, the lesson template, **Linkly v0**
(a tested URL shortener that runs without containers) and **Module 0: Foundations Check**, whose
last lab is running Linkly by hand on bare Linux.

**Architecture:** Linkly is three small services in `app/linkly/`:
- `api`: FastAPI. Postgres is behind a `LinkStore` protocol, so tests use an in-memory store; Redis is used through redis-py, so tests use `fakeredis`.
- `worker`: drains the Redis `clicks` list into Postgres.
- `web`: static HTML/JS served by nginx, which proxies `/api/` and `/r/` to the API.

Module 0 is Markdown lessons that follow the lesson template.

**Tech Stack:** Python 3.12+, FastAPI, uvicorn, psycopg 3, redis-py, pytest, httpx, fakeredis;
nginx; Ubuntu 24.04 (WSL2 or a VM) for the by-hand lab.

**Spec:** `docs/superpowers/specs/2026-10-14-course-design.md`

## Global Constraints

- Folder and file names are `NN-slug` (`/^\d{2}-[a-z0-9]+(?:-[a-z0-9]+)*$/`); a module's `README.md` starts with `# <Module title>`, and each lesson starts with `# <Lesson title>`. The JARVIS Course tab relies on this.
- Every lesson has these sections, in order: `## Why this matters`, `## Concept`, `## Example`, `## Lab` (a `- [ ]` checklist), `## Check yourself` (answers in `<details><summary>Answer</summary>…</details>`), optional `## Stretch`, and `## Clean up` whenever the lab creates cloud resources.
- Lab checklist items are unique within a lesson; ticks are saved by the item's text.
- Linkly config comes only from env vars: `DATABASE_URL`, `REDIS_URL` (default `redis://localhost:6379/0`), `BASE_URL` (default `http://localhost:8080`).
- Short codes are 7 characters of `[0-9A-Za-z]`; short links are `${BASE_URL}/r/<code>`.
- Module 0 needs no cloud and costs nothing.
- Licences: code is MIT and lesson text is CC BY 4.0. **Confirm with the author before publishing.**
- Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **Redis down while someone clicks a short link.** The redirect must still work (it falls back to Postgres) and the click is lost rather than the request failing. Pinned in Task 2 (`test_redirect_survives_redis_down`).
2. **Shortening something that isn't a web address** (`javascript:alert(1)`, `ftp://`, empty) must be rejected with 422 and never stored. Pinned in Task 2.
3. **Unknown or malformed codes** (`/r/abc`, `/r/../../etc`) must 404 without touching the database. Pinned in Task 2.
4. **The worker meets a burst of clicks for the same code.** It should batch them into one `+n` update rather than n round trips. Pinned in Task 3.
5. **A learner on Windows.** The by-hand lab must say plainly to use WSL2 Ubuntu (or a VM), with the exact install command, before any Linux step. Pinned in Task 5 (lesson 04 checklist).

---

## File Structure

```
devops-course/
  README.md                         course intro, module map, how to start, licences
  LICENSE                           MIT (code)
  LICENSE-CONTENT.md                CC BY 4.0 (lessons)
  .gitignore
  docs/lesson-template.md           the lesson skeleton authors copy
  app/linkly/
    README.md                       what Linkly is, how its parts talk
    api/requirements.txt, requirements-dev.txt
    api/linkly_api/{__init__,codes,store,main}.py
    api/tests/{test_codes,test_store,test_api}.py
    worker/requirements.txt, requirements-dev.txt
    worker/linkly_worker/{__init__,main}.py
    worker/tests/test_worker.py
    web/{index.html,app.js,style.css,nginx.conf}
  modules/00-foundations/
    README.md
    01-linux-refresher.md
    02-networking.md
    03-git.md
    04-run-linkly-by-hand.md
    05-self-test.md
```

---

### Task 1: Repo skeleton and lesson template

**Files:**
- Create: `README.md`, `LICENSE`, `LICENSE-CONTENT.md`, `.gitignore`, `docs/lesson-template.md`

**Interfaces:**
- Produces: the lesson template that every lesson in Task 5 follows.

- [ ] **Step 1: Write the files**

`.gitignore`:

```
__pycache__/
*.pyc
.venv/
.pytest_cache/
.env
```

`docs/lesson-template.md`:

```markdown
# <Lesson title>

> **You need:** <what from earlier lessons> · **Time:** <~N min> · **Start from:** `checkpoint/NN-<module>`

## Why this matters

<The problem, ideally one the learner just hit. 2-4 sentences. No tool names yet.>

## Concept

<The idea, independent of any tool. A diagram if it helps. Keep it short.>

## Example

<A worked walkthrough on Linkly: exact commands and what the output should look like.>

## Lab

- [ ] <one concrete action, checkable>
- [ ] <…>

## Check yourself

1. <question>

<details><summary>Answer</summary>

<answer>

</details>

## Stretch

<Optional, harder variation.>

## Clean up

<Required if the lab created anything that costs money or keeps running.>
```

`README.md`: the course title "DevOps, Layer by Layer"; one paragraph on who it is for (some tech background) and the idea (one app, Linkly, grows a layer per module); the full module map table copied from the spec (`#`, Module, What you add to Linkly); "How to start" (clone, open `modules/00-foundations/README.md`; the checkpoint branches `checkpoint/NN-<module>`); "Costs" (free until Module 6, AWS labs say their price and end with a clean-up); and the licences section (code MIT, lessons CC BY 4.0).

`LICENSE`: the standard MIT text, `Copyright (c) 2026 <author name>`. Ask the author for the name to use, and leave the placeholder until they answer.

`LICENSE-CONTENT.md`: "Lesson text and diagrams in `modules/` and `docs/` are licensed under Creative Commons Attribution 4.0 International (CC BY 4.0): https://creativecommons.org/licenses/by/4.0/".

- [ ] **Step 2: Verify**

Run: `git status` and open `README.md` in a Markdown preview.
Expected: the module map renders as a table with 13 rows (0–12); there are no TODO markers other than the author name in `LICENSE`.

- [ ] **Step 3: Commit**

```bash
git add README.md LICENSE LICENSE-CONTENT.md .gitignore docs/lesson-template.md
git commit -m "docs: course README, licences and lesson template"
```

---

### Task 2: Linkly API

**Files:**
- Create: `app/linkly/api/requirements.txt`, `app/linkly/api/requirements-dev.txt`
- Create: `app/linkly/api/linkly_api/__init__.py` (empty), `codes.py`, `store.py`, `main.py`
- Test: `app/linkly/api/tests/test_codes.py`, `test_store.py`, `test_api.py`

**Interfaces:**
- Produces:
  - `codes.new_code(length: int = 7) -> str`, `codes.CODE_RE`
  - `store.Link(code, url, clicks, created_at)`, `store.CodeTaken`, `store.LinkStore` (Protocol: `create(code, url) -> Link`, `get(code) -> Link | None`, `add_clicks(code, n) -> None`), `store.MemoryStore`, `store.PgStore(dsn)`
  - `main.create_app(store: LinkStore, cache: redis.Redis, base_url: str) -> FastAPI`, `main.app_from_env() -> FastAPI` (run with `uvicorn linkly_api.main:app_from_env --factory`)
  - HTTP: `POST /api/links {url}` → 201 `{code, url, short_url}`; `GET /r/{code}` → 307; `GET /api/links/{code}` → `{code, url, clicks, created_at}`; `GET /healthz` → `{status: "ok"}`
  - Redis contract (used by the worker in Task 3): every redirect does `LPUSH clicks <code>`; the cache key is `link:<code>`, with a TTL of 3600 s.

- [ ] **Step 1: Set up the environment**

`app/linkly/api/requirements.txt`:

```
fastapi>=0.115
uvicorn[standard]>=0.30
psycopg[binary]>=3.2
redis>=5.0
```

`app/linkly/api/requirements-dev.txt`:

```
-r requirements.txt
pytest>=8
httpx>=0.27
fakeredis>=2.23
```

Run (from `app/linkly/api`): `py -3.13 -m venv .venv` then `.venv/Scripts/python -m pip install -r requirements-dev.txt`. On Linux or WSL, use `python3 -m venv .venv` and `.venv/bin/python`.

- [ ] **Step 2: Write the failing tests**

`app/linkly/api/tests/test_codes.py`:

```python
from linkly_api.codes import CODE_RE, new_code


def test_codes_are_seven_url_safe_characters_and_vary():
    codes = {new_code() for _ in range(200)}
    assert all(CODE_RE.fullmatch(c) for c in codes)
    assert len(codes) == 200
```

`app/linkly/api/tests/test_store.py`:

```python
import os

import pytest

from linkly_api.store import CodeTaken, MemoryStore, PgStore


def stores():
    yield MemoryStore()
    dsn = os.environ.get("LINKLY_TEST_DATABASE_URL")
    if dsn:  # optional: a throwaway Postgres, e.g. on WSL
        s = PgStore(dsn)
        s.reset_for_tests()
        yield s


@pytest.mark.parametrize("store", list(stores()), ids=lambda s: type(s).__name__)
def test_create_get_and_count_clicks(store):
    link = store.create("abc1234", "https://example.com/a")
    assert (link.code, link.url, link.clicks) == ("abc1234", "https://example.com/a", 0)
    store.add_clicks("abc1234", 3)
    assert store.get("abc1234").clicks == 3
    assert store.get("nope000") is None
    with pytest.raises(CodeTaken):
        store.create("abc1234", "https://example.com/b")
```

`app/linkly/api/tests/test_api.py`:

```python
import fakeredis
import pytest
import redis
from fastapi.testclient import TestClient

from linkly_api.main import create_app
from linkly_api.store import MemoryStore


@pytest.fixture
def env():
    store, cache = MemoryStore(), fakeredis.FakeRedis(decode_responses=True)
    client = TestClient(create_app(store, cache, "http://short.test"), follow_redirects=False)
    return client, store, cache


def shorten(client, url="https://example.com/some/long/path?x=1"):
    res = client.post("/api/links", json={"url": url})
    assert res.status_code == 201, res.text
    return res.json()


def test_shorten_then_redirect_counts_a_click_on_the_queue(env):
    client, _, cache = env
    body = shorten(client)
    assert body["short_url"] == f"http://short.test/r/{body['code']}"
    res = client.get(f"/r/{body['code']}")
    assert res.status_code == 307
    assert res.headers["location"] == "https://example.com/some/long/path?x=1"
    assert cache.lrange("clicks", 0, -1) == [body["code"]]
    assert cache.get(f"link:{body['code']}") == "https://example.com/some/long/path?x=1"


def test_stats(env):
    client, store, _ = env
    code = shorten(client)["code"]
    store.add_clicks(code, 2)
    stats = client.get(f"/api/links/{code}").json()
    assert stats["clicks"] == 2 and stats["url"].startswith("https://example.com")


@pytest.mark.parametrize("url", ["javascript:alert(1)", "ftp://example.com/x", "", "not a url"])
def test_only_web_addresses_are_shortened(env, url):
    client, store, _ = env
    assert client.post("/api/links", json={"url": url}).status_code == 422
    assert store.count() == 0


@pytest.mark.parametrize("path", ["/r/abc", "/r/abcdefgh", "/r/ab%2F..12", "/r/zzzzzzz", "/api/links/zzzzzzz"])
def test_unknown_or_malformed_codes_404(env, path):
    client, _, _ = env
    assert client.get(path).status_code == 404


class DownRedis:
    """Every call fails, like a Redis that has stopped."""

    def __getattr__(self, name):
        def fail(*args, **kwargs):
            raise redis.ConnectionError("redis is down")
        return fail


def test_redirect_survives_redis_down(env):
    client, _, _ = env
    code = shorten(client)["code"]
    client.app.state.cache = DownRedis()
    res = client.get(f"/r/{code}")
    assert res.status_code == 307
    assert res.headers["location"].startswith("https://example.com")


def test_healthz(env):
    client, _, _ = env
    assert client.get("/healthz").json() == {"status": "ok"}
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `.venv/Scripts/python -m pytest -q`
Expected: FAIL with `ModuleNotFoundError: No module named 'linkly_api.codes'` (and similar).

- [ ] **Step 4: Write the implementation**

`app/linkly/api/linkly_api/codes.py`:

```python
import re
import secrets
import string

ALPHABET = string.digits + string.ascii_letters
CODE_RE = re.compile(r"[0-9A-Za-z]{7}")


def new_code(length: int = 7) -> str:
    """A random short code like 'a8Zk2Qp'. 62^7 ≈ 3.5 trillion possibilities."""
    return "".join(secrets.choice(ALPHABET) for _ in range(length))
```

`app/linkly/api/linkly_api/store.py`:

```python
from dataclasses import dataclass, replace
from datetime import datetime, timezone
from typing import Protocol

import psycopg
from psycopg.rows import class_row


@dataclass(frozen=True)
class Link:
    code: str
    url: str
    clicks: int
    created_at: datetime


class CodeTaken(Exception):
    """Another link already has this code."""


class LinkStore(Protocol):
    def create(self, code: str, url: str) -> Link: ...
    def get(self, code: str) -> Link | None: ...
    def add_clicks(self, code: str, n: int) -> None: ...


class MemoryStore:
    """For tests (and for reading the code: this is the whole contract)."""

    def __init__(self) -> None:
        self._links: dict[str, Link] = {}

    def create(self, code: str, url: str) -> Link:
        if code in self._links:
            raise CodeTaken(code)
        self._links[code] = Link(code, url, 0, datetime.now(timezone.utc))
        return self._links[code]

    def get(self, code: str) -> Link | None:
        return self._links.get(code)

    def add_clicks(self, code: str, n: int) -> None:
        if code in self._links:
            self._links[code] = replace(self._links[code], clicks=self._links[code].clicks + n)

    def count(self) -> int:
        return len(self._links)


SCHEMA = """
CREATE TABLE IF NOT EXISTS links (
  code TEXT PRIMARY KEY,
  url TEXT NOT NULL,
  clicks BIGINT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
)
"""


class PgStore:
    """Postgres. One short connection per call: simple to read; Module 8 revisits this with pooling."""

    def __init__(self, dsn: str) -> None:
        self.dsn = dsn
        with self._conn() as c:
            c.execute(SCHEMA)

    def _conn(self) -> psycopg.Connection:
        return psycopg.connect(self.dsn, autocommit=True)

    def create(self, code: str, url: str) -> Link:
        try:
            with self._conn() as c, c.cursor(row_factory=class_row(Link)) as cur:
                cur.execute("INSERT INTO links (code, url) VALUES (%s, %s) RETURNING code, url, clicks, created_at", (code, url))
                return cur.fetchone()
        except psycopg.errors.UniqueViolation as e:
            raise CodeTaken(code) from e

    def get(self, code: str) -> Link | None:
        with self._conn() as c, c.cursor(row_factory=class_row(Link)) as cur:
            cur.execute("SELECT code, url, clicks, created_at FROM links WHERE code = %s", (code,))
            return cur.fetchone()

    def add_clicks(self, code: str, n: int) -> None:
        with self._conn() as c:
            c.execute("UPDATE links SET clicks = clicks + %s WHERE code = %s", (n, code))

    def count(self) -> int:
        with self._conn() as c:
            return c.execute("SELECT count(*) FROM links").fetchone()[0]

    def reset_for_tests(self) -> None:
        with self._conn() as c:
            c.execute("TRUNCATE links")
```

`app/linkly/api/linkly_api/main.py`:

```python
import logging
import os

import redis
from fastapi import FastAPI, HTTPException
from fastapi.responses import RedirectResponse
from pydantic import AnyHttpUrl, BaseModel

from .codes import CODE_RE, new_code
from .store import CodeTaken, LinkStore, PgStore

log = logging.getLogger("linkly")
CACHE_TTL = 3600


class NewLink(BaseModel):
    url: AnyHttpUrl  # http and https only: javascript:, ftp: and friends get a 422


def create_app(store: LinkStore, cache: redis.Redis, base_url: str) -> FastAPI:
    app = FastAPI(title="Linkly")
    app.state.cache = cache

    def known(code: str):
        link = store.get(code) if CODE_RE.fullmatch(code) else None
        if link is None:
            raise HTTPException(404, "No such link")
        return link

    @app.get("/healthz")
    def healthz():
        return {"status": "ok"}

    @app.post("/api/links", status_code=201)
    def shorten(body: NewLink):
        url = str(body.url)
        for _ in range(5):  # a clash is astronomically unlikely, but cheap to handle
            try:
                link = store.create(new_code(), url)
                return {"code": link.code, "url": link.url, "short_url": f"{base_url}/r/{link.code}"}
            except CodeTaken:
                continue
        raise HTTPException(503, "Couldn't find a free code, try again")

    @app.get("/r/{code}")
    def go(code: str):
        c: redis.Redis = app.state.cache
        url = None
        try:
            url = c.get(f"link:{code}")
        except redis.RedisError:
            log.warning("redis unavailable; reading %s from postgres", code)
        if url is None:
            url = known(code).url
            try:
                c.set(f"link:{code}", url, ex=CACHE_TTL)
            except redis.RedisError:
                pass
        try:
            c.lpush("clicks", code)  # the worker turns these into counts
        except redis.RedisError:
            log.warning("redis unavailable; click on %s not counted", code)
        return RedirectResponse(url, status_code=307)

    @app.get("/api/links/{code}")
    def stats(code: str):
        link = known(code)
        return {"code": link.code, "url": link.url, "clicks": link.clicks, "created_at": link.created_at.isoformat()}

    return app


def app_from_env() -> FastAPI:
    """uvicorn linkly_api.main:app_from_env --factory"""
    return create_app(
        PgStore(os.environ["DATABASE_URL"]),
        redis.Redis.from_url(os.environ.get("REDIS_URL", "redis://localhost:6379/0"), decode_responses=True, socket_timeout=1),
        os.environ.get("BASE_URL", "http://localhost:8080").rstrip("/"),
    )
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `.venv/Scripts/python -m pytest -q`
Expected: all PASS. The Postgres case of `test_store` runs only when `LINKLY_TEST_DATABASE_URL` is set; Task 4 runs it.

- [ ] **Step 6: Commit**

```bash
git add app/linkly/api
git commit -m "feat(linkly): API - shorten, redirect (cached, click queued), stats"
```

---

### Task 3: Linkly worker

**Files:**
- Create: `app/linkly/worker/requirements.txt` (`psycopg[binary]>=3.2`, `redis>=5.0`), `requirements-dev.txt` (`-r requirements.txt`, `pytest>=8`, `fakeredis>=2.23`)
- Create: `app/linkly/worker/linkly_worker/__init__.py` (empty), `main.py`
- Test: `app/linkly/worker/tests/test_worker.py`

**Interfaces:**
- Consumes: the Redis list `clicks` (codes, pushed with LPUSH by the API) and the table `links(code, clicks)`.
- Produces: `drain(r: redis.Redis, add: Callable[[str, int], None], batch: int = 100, timeout: int = 5) -> int` (clicks applied); `main()`.

- [ ] **Step 1: Write the failing test**

```python
import fakeredis

from linkly_worker.main import drain


def test_drain_batches_clicks_per_code():
    r = fakeredis.FakeRedis(decode_responses=True)
    for code in ["aaaaaaa", "bbbbbbb", "aaaaaaa", "aaaaaaa"]:
        r.lpush("clicks", code)
    applied: list[tuple[str, int]] = []
    assert drain(r, lambda code, n: applied.append((code, n)), timeout=1) == 4
    assert sorted(applied) == [("aaaaaaa", 3), ("bbbbbbb", 1)]
    assert r.llen("clicks") == 0


def test_drain_respects_batch_size_and_returns_zero_when_idle():
    r = fakeredis.FakeRedis(decode_responses=True)
    for _ in range(5):
        r.lpush("clicks", "ccccccc")
    applied = []
    assert drain(r, lambda c, n: applied.append(n), batch=2, timeout=1) == 2
    assert r.llen("clicks") == 3
    empty = fakeredis.FakeRedis(decode_responses=True)
    assert drain(empty, lambda c, n: None, timeout=1) == 0
```

- [ ] **Step 2: Run it to verify it fails**

Run (in `app/linkly/worker`, after creating `.venv` and installing `requirements-dev.txt`): `.venv/Scripts/python -m pytest -q`
Expected: FAIL with `ModuleNotFoundError: No module named 'linkly_worker.main'`.

- [ ] **Step 3: Write the implementation**

`app/linkly/worker/linkly_worker/main.py`:

```python
import logging
import os
from collections import Counter
from typing import Callable

import psycopg
import redis

log = logging.getLogger("linkly-worker")


def drain(r: redis.Redis, add: Callable[[str, int], None], batch: int = 100, timeout: int = 5) -> int:
    """Wait up to `timeout` s for a click, take up to `batch`, and apply them as one +n per code."""
    first = r.brpop(["clicks"], timeout=timeout)
    if not first:
        return 0
    counts = Counter([first[1]])
    while sum(counts.values()) < batch:
        code = r.rpop("clicks")
        if code is None:
            break
        counts[code] += 1
    for code, n in counts.items():
        add(code, n)
    return sum(counts.values())


def main() -> None:
    logging.basicConfig(level=logging.INFO)
    r = redis.Redis.from_url(os.environ.get("REDIS_URL", "redis://localhost:6379/0"), decode_responses=True)
    dsn = os.environ["DATABASE_URL"]

    def add(code: str, n: int) -> None:
        with psycopg.connect(dsn, autocommit=True) as c:
            c.execute("UPDATE links SET clicks = clicks + %s WHERE code = %s", (n, code))

    log.info("worker started")
    while True:
        if n := drain(r, add):
            log.info("counted %d clicks", n)


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `.venv/Scripts/python -m pytest -q`
Expected: 2 PASS.

- [ ] **Step 5: Commit**

```bash
git add app/linkly/worker
git commit -m "feat(linkly): worker - batch queued clicks into the counts"
```

---

### Task 4: Linkly web, nginx and an end-to-end run on Linux

**Files:**
- Create: `app/linkly/web/index.html`, `app/linkly/web/app.js`, `app/linkly/web/style.css`, `app/linkly/web/nginx.conf`
- Create: `app/linkly/README.md`

**Interfaces:**
- Consumes: the HTTP API from Task 2.
- Produces: `nginx.conf`, which Lesson 04 installs and Module 1 later changes (upstream `127.0.0.1:8000` → `api:8000`).

- [ ] **Step 1: Write the web files**

`app/linkly/web/index.html`:

```html
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Linkly</title>
  <link rel="stylesheet" href="/style.css">
</head>
<body>
  <main>
    <h1>Linkly</h1>
    <p>Paste a long link, get a short one.</p>
    <form id="shorten">
      <label for="url">Long link</label>
      <input id="url" name="url" type="url" required placeholder="https://…">
      <button type="submit">Shorten</button>
    </form>
    <p id="error" role="alert" hidden></p>
    <section id="result" hidden>
      <p>Short link: <a id="short" target="_blank" rel="noreferrer"></a></p>
      <p>Clicks: <strong id="clicks">0</strong> <button type="button" id="refresh">Refresh</button></p>
    </section>
  </main>
  <script src="/app.js"></script>
</body>
</html>
```

`app/linkly/web/app.js`:

```js
const $ = (id) => document.getElementById(id);
let code = null;

async function refresh() {
  if (!code) return;
  const res = await fetch(`/api/links/${code}`);
  if (res.ok) $("clicks").textContent = (await res.json()).clicks;
}

$("shorten").addEventListener("submit", async (e) => {
  e.preventDefault();
  $("error").hidden = true;
  const res = await fetch("/api/links", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ url: $("url").value }),
  });
  if (!res.ok) {
    $("error").textContent = res.status === 422 ? "That doesn't look like a web address." : `Something went wrong (${res.status}).`;
    $("error").hidden = false;
    return;
  }
  const link = await res.json();
  code = link.code;
  $("short").href = $("short").textContent = link.short_url;
  $("clicks").textContent = "0";
  $("result").hidden = false;
});

$("refresh").addEventListener("click", refresh);
```

`app/linkly/web/style.css`:

```css
:root { --ink: #14181d; --muted: #687280; --accent: #1f4fd1; --page: #f5f6f8; --surface: #fff; color-scheme: light dark; }
@media (prefers-color-scheme: dark) { :root { --ink: #e8eaee; --muted: #9aa3b0; --accent: #7aa2ff; --page: #111418; --surface: #1a1e24; } }
body { margin: 0; background: var(--page); color: var(--ink); font: 17px/1.5 system-ui, sans-serif; }
main { max-width: 560px; margin: 10vh auto; padding: 24px 16px; }
form { display: flex; flex-wrap: wrap; gap: 8px; }
label { width: 100%; color: var(--muted); }
input { flex: 1 1 240px; padding: 10px 12px; border: 1px solid var(--muted); border-radius: 8px; background: var(--surface); color: var(--ink); font: inherit; }
button { padding: 10px 16px; border: 0; border-radius: 8px; background: var(--accent); color: #fff; font: inherit; cursor: pointer; }
#result { margin-top: 20px; padding: 14px 16px; border-radius: 10px; background: var(--surface); }
#error { color: #c2382e; }
a { color: var(--accent); word-break: break-all; }
```

`app/linkly/web/nginx.conf`:

```nginx
# Linkly's front door: static files, and /api/ + /r/ passed to the API.
server {
    listen 8080;
    root /var/www/linkly;
    index index.html;

    location /api/ { proxy_pass http://127.0.0.1:8000; proxy_set_header Host $host; proxy_set_header X-Forwarded-For $remote_addr; }
    location /r/   { proxy_pass http://127.0.0.1:8000; proxy_set_header Host $host; proxy_set_header X-Forwarded-For $remote_addr; }
    location /     { try_files $uri $uri/ =404; }
}
```

`app/linkly/README.md`: a short diagram, then one line per part.

```
browser → nginx :8080 ─┬─ static files (web/)
                       └─ /api/, /r/ → api :8000 ─┬─ postgres (links, counts)
                                                  └─ redis (cache, "clicks" queue) ← worker → postgres
```

Then list each service's env vars (`DATABASE_URL`, `REDIS_URL`, `BASE_URL`), how to run the tests, and "To run it by hand, see `modules/00-foundations/04-run-linkly-by-hand.md`".

- [ ] **Step 2: Run the whole thing on Linux (WSL2 Ubuntu or a VM)**

These are exactly the steps Lesson 04 teaches, so do them once here to prove they work:

```bash
sudo apt update && sudo apt install -y python3-venv postgresql redis-server nginx
sudo -u postgres psql -c "CREATE USER linkly WITH PASSWORD 'linkly';" -c "CREATE DATABASE linkly OWNER linkly;"
export DATABASE_URL=postgresql://linkly:linkly@localhost:5432/linkly REDIS_URL=redis://localhost:6379/0 BASE_URL=http://localhost:8080
cd app/linkly/api && python3 -m venv .venv && .venv/bin/pip install -r requirements-dev.txt
LINKLY_TEST_DATABASE_URL=$DATABASE_URL .venv/bin/python -m pytest -q          # now includes the Postgres store test
.venv/bin/uvicorn linkly_api.main:app_from_env --factory --port 8000 &        # terminal 1 in the lesson
cd ../worker && python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
.venv/bin/python -m linkly_worker.main &                                      # terminal 2 in the lesson
sudo mkdir -p /var/www/linkly && sudo cp ../web/*.html ../web/*.js ../web/*.css /var/www/linkly/
sudo cp ../web/nginx.conf /etc/nginx/sites-available/linkly && sudo ln -sf /etc/nginx/sites-available/linkly /etc/nginx/sites-enabled/linkly
sudo nginx -t && sudo systemctl reload nginx
curl -s -X POST localhost:8080/api/links -H 'content-type: application/json' -d '{"url":"https://example.com"}'
```

Expected:
- pytest passes, including `test_create_get_and_count_clicks[PgStore]`.
- curl returns `{"code":"…","url":"https://example.com/","short_url":"http://localhost:8080/r/…"}`.
- `curl -si localhost:8080/r/<code>` returns `307` with `location: https://example.com/`.
- After about 5 s, `curl -s localhost:8080/api/links/<code>` shows `"clicks":1`.
- http://localhost:8080 works in a browser (WSL2 forwards localhost).

Write down anything that went wrong; it becomes a "Common problems" section in Lesson 04.

Stop the background processes afterwards (`kill %1 %2`).

- [ ] **Step 3: Commit**

```bash
git add app/linkly/web app/linkly/README.md
git commit -m "feat(linkly): web page and nginx front door; Linkly README"
```

---

### Task 5: Module 0, Foundations Check

**Files:**
- Create: `modules/00-foundations/README.md` and the five lessons below.

**Interfaces:**
- Consumes: the lesson template (Task 1); Linkly v0 and the verified by-hand steps (Tasks 2–4).
- Produces: lessons the JARVIS Course tab can read: an `NN-slug` name, an `# ` title first, and unique `- [ ]` lab items.

The author learns by doing these labs, then rewrites the prose in their own voice. That is the authoring loop from the spec. Each lesson below gives the required content; write it into the template's sections.

- [ ] **Step 1: Module README**

`modules/00-foundations/README.md` starts with `# Foundations Check`. It covers:
- **Who it's for:** "You've used a terminal and Git before; this checks it and fills gaps."
- **What you'll build:** Linkly running by hand on Linux.
- **Time:** about 6–8 hours.
- **Start from:** `checkpoint/00-foundations`.
- **Windows users:** install WSL2 first with `wsl --install -d Ubuntu-24.04` in an admin PowerShell, then reboot.
- The lesson list, with one line per lesson.

- [ ] **Step 2: `01-linux-refresher.md`, "# Linux refresher"**

| Section | Content |
|---|---|
| Why | Every server, container and CI runner you'll touch is Linux. |
| Concept | The filesystem tree (`/etc`, `/var/log`, `/home`, `/usr/bin`); users, groups and `rwx` permissions; processes and signals; packages (`apt`); services (`systemctl`); environment variables. |
| Example | `ls -la /etc`, `cat /etc/os-release`, `ps aux \| grep nginx`, `chmod 640 notes.txt` then `ls -l`, `sudo systemctl status ssh`, `echo $PATH`, `export GREETING=hi; bash -c 'echo $GREETING'`. |

**Lab:**
- [ ] Find which Ubuntu version you're on
- [ ] Create a user `deploy` and a group `apps`, and add `deploy` to `apps`
- [ ] Make a file only `deploy` can read and prove another user can't
- [ ] Install `htop` with apt and find the process using the most memory
- [ ] Write a script `hello.sh` that prints the date and your user, make it executable, and run it
- [ ] Explain in one sentence why `export` mattered in the `GREETING` example

**Check yourself:** what does `chmod 750` mean; where do service logs go (`journalctl -u <name>`); what's the difference between `kill` and `kill -9`; why use `sudo` instead of logging in as root.

**Stretch:** a `systemd` timer that runs `hello.sh` every minute.

- [ ] **Step 3: `02-networking.md`, "# Networking for DevOps"**

| Section | Content |
|---|---|
| Why | "It works on my machine but not from yours" is almost always ports, DNS or a firewall. |
| Concept | IP and ports, localhost vs `0.0.0.0`, DNS (A/CNAME), HTTP request/response and status codes, TLS in one paragraph, reverse proxies (sets up Lesson 04's nginx). |
| Example | `ip a`, `ss -tlnp`, `dig example.com`, `curl -v https://example.com`, `python3 -m http.server 9000` then `curl localhost:9000`, then binding to `127.0.0.1` vs `0.0.0.0` and testing from Windows. |

**Lab:**
- [ ] List every port listening on your machine and name the program behind each
- [ ] Resolve `github.com` and say which IP your machine would use
- [ ] Start a web server on port 9000 and reach it from your Windows browser
- [ ] Make the same server unreachable from outside by binding it to 127.0.0.1
- [ ] Read a `curl -v` output and point at the status line, the headers and the body

**Check yourself:** what a 301, 404 and 502 each tell you; why a reverse proxy; what `EADDRINUSE` means.

- [ ] **Step 4: `03-git.md`, "# Git refresher"**

| Section | Content |
|---|---|
| Why | Everything in DevOps is code in Git: app, pipelines, infrastructure. Git is the audit log. |
| Concept | Commits as snapshots; branches as pointers; remotes; merge vs rebase; `.gitignore`; never commit secrets (and what to do if you did). |
| Example | Fork and clone this course repo; `git switch -c my-notes`; edit, `git add -p`, commit, push; open a PR; `git log --oneline --graph`. |

**Lab:**
- [ ] Clone your fork of the course repo
- [ ] Check out `checkpoint/00-foundations`
- [ ] Create a branch, change Linkly's page title, commit and push it
- [ ] Make a merge conflict on purpose and resolve it
- [ ] Add a `.env` file and prove `.gitignore` keeps it out of `git status`

**Check yourself:** `git reset` vs `git revert`; what `origin` is; why rebasing shared branches hurts.

- [ ] **Step 5: `04-run-linkly-by-hand.md`, "# Run Linkly by hand"**

| Section | Content |
|---|---|
| Why | Before automating anything, feel what you're automating. |
| Concept | Linkly's diagram (copy it from `app/linkly/README.md`); what each part needs (runtime, config, a port, a dependency). |
| Example | The exact command sequence verified in Task 4 Step 2, in small steps, each with its expected output. Add a "Common problems" box built from the notes taken in Task 4. |

**Lab:**
- [ ] On Windows, install WSL2 Ubuntu first (`wsl --install -d Ubuntu-24.04`)
- [ ] Install Postgres, Redis, nginx and Python's venv with apt
- [ ] Create the `linkly` database and user
- [ ] Start the API on port 8000 and see `/healthz` answer
- [ ] Start the worker
- [ ] Put the web page behind nginx on port 8080
- [ ] Shorten a link in the browser, click it, and see the click count go up
- [ ] Stop Redis (`sudo systemctl stop redis-server`), click your link again, and explain what still works and what doesn't
- [ ] Write down every manual step you took and how long it took

The last item is the payoff: "Module 1 turns this whole list into one command."

**Check yourself:** what would break if the server rebooted; how you'd run two copies of the API; where the click count lives while Redis is down.

**Stretch:** systemd units for the API and the worker so they survive a reboot.

- [ ] **Step 6: `05-self-test.md`, "# Foundations self-test"**

- **Lab:** one checklist item per skill the module covers, phrased "I can …", e.g. "I can find which process is listening on a port". There are 12 items, all unique.
- **Check yourself:** 10 mixed questions with answers in `<details>`.
- **Closing line:** "Not sure about 3 or more? Redo that lesson's lab before Module 1."

- [ ] **Step 7: Verify the format (as the Course tab will read it)**

```bash
cd modules/00-foundations
for f in *.md; do head -n1 "$f" | grep -q '^# ' || echo "MISSING TITLE: $f"; done
ls | grep -Ev '^(README|[0-9]{2}-[a-z0-9]+(-[a-z0-9]+)*)\.md$' && echo "BAD NAME ABOVE"
for f in 0*.md; do grep -o '^- \[ \] .*' "$f" | sort | uniq -d | sed "s|^|DUPLICATE in $f: |"; done
for f in 0*.md; do for s in "## Why this matters" "## Concept" "## Example" "## Lab" "## Check yourself"; do grep -q "^$s" "$f" || echo "$f lacks $s"; done; done
```

Expected: no output, except that `05-self-test.md` may lack `## Concept`/`## Example`, which is allowed for the self-test only. Then point JARVIS at the repo (it's the default path) and open the Course tab: Module 0 shows 5 lessons with the right titles.

- [ ] **Step 8: Commit**

```bash
git add modules/00-foundations
git commit -m "docs(module-0): Foundations Check - Linux, networking, Git, Linkly by hand, self-test"
```

---

### Task 6: Checkpoint branches

**Files:** none (git refs only)

- [ ] **Step 1: Create the checkpoints**

Module 0 starts from Linkly v0, and Module 1 also starts from it (no Dockerfiles yet):

```bash
git branch checkpoint/00-foundations main
git branch checkpoint/01-containers main
git branch --list 'checkpoint/*'
```

Expected: both branches listed.

- [ ] **Step 2: Note it in the README**

In `README.md` under "How to start", add: "Each module's README names the branch to start from; `checkpoint/01-containers` is Linkly as it stands at the end of Module 0."

```bash
git add README.md
git commit -m "docs: checkpoint branches for modules 0 and 1"
```

Publishing to GitHub (creating the public repo and pushing) is a separate, explicit step. Ask the author first.
