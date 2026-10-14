import logging
import os
import signal
import threading
import time
from collections import Counter
from collections.abc import Callable

import psycopg
import redis

log = logging.getLogger("linkly-worker")
BLOCK_SECONDS = 2  # how long one wait for a click lasts; also how long a stop request can take to be noticed


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
    pending = dict(counts)
    try:
        for code, n in counts.items():
            add(code, n)
            del pending[code]
    except Exception:
        # Couldn't save them (Postgres down?): put the unsaved clicks back so none are lost.
        for code, n in pending.items():
            r.rpush("clicks", *[code] * n)
        raise
    return sum(counts.values())


def step(r: redis.Redis, add: Callable[[str, int], None], sleep: Callable[[float], None] = time.sleep) -> int:
    """One round of work. If Redis or Postgres is down, say so and wait a little instead of crashing:
    clicks wait in the queue."""
    try:
        return drain(r, add)
    except (redis.RedisError, psycopg.Error) as e:
        which = "redis" if isinstance(e, redis.RedisError) else "postgres"
        log.warning("%s unavailable (%s); retrying in 2 s", which, e)
        sleep(2)
        return 0


def stop_on_sigterm(stop: threading.Event):
    """`docker stop` sends SIGTERM to the container's first process (PID 1). Python ignores it there
    unless we handle it, and Docker then kills the worker after a grace period (exit code 137)."""

    def handle(signum, frame) -> None:
        log.info("stop requested; finishing the current batch")
        stop.set()

    return handle


def serve(r: redis.Redis, add: Callable[[str, int], None], stop: threading.Event) -> None:
    """Work until asked to stop. A batch already taken off the queue is always saved (or put back) first."""
    while not stop.is_set():
        if n := step(r, add):
            log.info("counted %d clicks", n)


def main() -> None:
    logging.basicConfig(level=logging.INFO)
    r = connect(os.environ.get("REDIS_URL", "redis://localhost:6379/0"))
    dsn = os.environ["DATABASE_URL"]

    def add(code: str, n: int) -> None:
        with psycopg.connect(dsn, autocommit=True) as c:
            c.execute("UPDATE links SET clicks = clicks + %s WHERE code = %s", (n, code))

    stop = threading.Event()
    signal.signal(signal.SIGTERM, stop_on_sigterm(stop))
    log.info("worker started")
    serve(r, add, stop)
    log.info("worker stopped")


if __name__ == "__main__":
    main()
