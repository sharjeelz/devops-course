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
        return {"status": "ok", "version": os.environ.get("LINKLY_VERSION", "dev")}

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
