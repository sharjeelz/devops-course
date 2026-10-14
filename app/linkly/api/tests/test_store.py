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
