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


def test_healthz_reports_the_version(env, monkeypatch):
    client, _, _ = env
    assert client.get("/healthz").json() == {"status": "ok", "version": "dev"}
    monkeypatch.setenv("LINKLY_VERSION", "0.2.0")
    assert client.get("/healthz").json() == {"status": "ok", "version": "0.2.0"}
