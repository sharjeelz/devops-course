import fakeredis
import psycopg
import redis
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


def test_connection_waits_longer_than_a_blocking_read():
    # redis-py 8 times sockets out after 5 s by default, which cut BRPOP's 5 s wait short and crashed the worker.
    from linkly_worker.main import BLOCK_SECONDS, connect

    r = connect("redis://localhost:6379/0")
    assert r.connection_pool.connection_kwargs["socket_timeout"] > BLOCK_SECONDS


class DownRedis:
    def __getattr__(self, name):
        def fail(*args, **kwargs):
            raise redis.ConnectionError("redis is down")
        return fail


def test_step_survives_redis_being_down():
    from linkly_worker.main import step

    waited = []
    assert step(DownRedis(), lambda c, n: None, sleep=waited.append) == 0
    assert waited == [2]


def test_step_puts_clicks_back_when_postgres_is_down():
    from linkly_worker.main import step

    r = fakeredis.FakeRedis(decode_responses=True)
    for code in ["aaaaaaa", "aaaaaaa", "bbbbbbb"]:
        r.lpush("clicks", code)

    def postgres_down(code, n):
        raise psycopg.OperationalError("connection refused")

    waited = []
    assert step(r, postgres_down, sleep=waited.append) == 0
    assert waited == [2]
    assert sorted(r.lrange("clicks", 0, -1)) == ["aaaaaaa", "aaaaaaa", "bbbbbbb"]


def test_serve_stops_when_asked():
    # Docker stops a container by sending SIGTERM to PID 1; the worker must notice and exit, not be killed.
    import threading

    from linkly_worker.main import serve, stop_on_sigterm

    stop = threading.Event()
    stop_on_sigterm(stop)(15, None)
    assert stop.is_set()

    r = fakeredis.FakeRedis(decode_responses=True)
    r.lpush("clicks", "aaaaaaa")
    seen = []

    def add(code, n):
        seen.append((code, n))
        stop.set()

    stop.clear()
    serve(r, add, stop)  # returns once stop is set, after finishing the batch in hand
    assert seen == [("aaaaaaa", 1)]
