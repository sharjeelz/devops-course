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


@pytest.mark.skipif(not os.environ.get("LINKLY_TEST_DATABASE_URL"), reason="needs a real Postgres")
def test_replicas_starting_at_once_dont_trip_over_the_schema():
    # Two API replicas starting together both run CREATE TABLE IF NOT EXISTS; without a lock Postgres
    # can fail one of them with a duplicate-key error on its type catalog (seen on Kubernetes).
    from concurrent.futures import ThreadPoolExecutor

    import psycopg

    dsn = os.environ["LINKLY_TEST_DATABASE_URL"]
    for _ in range(15):
        with psycopg.connect(dsn, autocommit=True) as c:
            c.execute("DROP TABLE IF EXISTS links")
        with ThreadPoolExecutor(max_workers=8) as pool:
            list(pool.map(lambda _: PgStore(dsn), range(8)))  # raises if any start-up failed
