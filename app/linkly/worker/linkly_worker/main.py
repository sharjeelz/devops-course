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
