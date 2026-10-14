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
