from dataclasses import dataclass, replace
from datetime import UTC, datetime
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
        self._links[code] = Link(code, url, 0, datetime.now(UTC))
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
                cur.execute(
                    "INSERT INTO links (code, url) VALUES (%s, %s) RETURNING code, url, clicks, created_at", (code, url)
                )
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
