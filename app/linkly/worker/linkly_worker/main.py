import logging
import os
import time
from collections import Counter
from typing import Callable

import psycopg
import redis

log = logging.getLogger("linkly-worker")
BLOCK_SECONDS = 5  # how long one wait for a click lasts


def connect(url: str) -> redis.Redis:
    """The socket must outlast a blocking wait, or the client gives up on BRPOP before Redis answers."""
    return redis.Redis.from_url(url, decode_responses=True, socket_timeout=BLOCK_SECONDS + 5)


def drain(r: redis.Redis, add: Callable[[str, int], None], batch: int = 100, timeout: int = BLOCK_SECONDS) -> int:
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


def step(r: redis.Redis, add: Callable[[str, int], None], sleep: Callable[[float], None] = time.sleep) -> int:
    """One round of work. If Redis is down, say so and wait a little instead of crashing: clicks wait in the queue."""
    try:
        return drain(r, add)
    except redis.RedisError as e:
        log.warning("redis unavailable (%s); retrying in 2 s", e)
        sleep(2)
        return 0


def main() -> None:
    logging.basicConfig(level=logging.INFO)
    r = connect(os.environ.get("REDIS_URL", "redis://localhost:6379/0"))
    dsn = os.environ["DATABASE_URL"]

    def add(code: str, n: int) -> None:
        with psycopg.connect(dsn, autocommit=True) as c:
            c.execute("UPDATE links SET clicks = clicks + %s WHERE code = %s", (n, code))

    log.info("worker started")
    while True:
        if n := step(r, add):
            log.info("counted %d clicks", n)


if __name__ == "__main__":
    main()
