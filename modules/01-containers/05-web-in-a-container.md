# The web front door in a container

> **You need:** Lesson 4 (and `linkly-net`, `postgres`, `redis` from lesson 2) · **Time:** ~60 min · **Start from:** `checkpoint/01-containers`

## Why this matters

nginx was the last thing you configured by hand in Module 0: copy files into `/var/www`, copy a
config into `sites-available`, symlink it, reload. As an image, it's two `COPY` lines. And this
lesson is the first time you'll run **all five** parts of Linkly as containers.

## Concept

The container version of the nginx config, `app/linkly/web/nginx.container.conf`, differs from
Module 0's `nginx.conf` in one important way:

```diff
-    location /api/ { proxy_pass http://127.0.0.1:8000; ... }
+    location /api/ { proxy_pass http://api:8000; ... }
```

In Module 0, nginx and the API ran on the same machine, so `127.0.0.1` worked. Now nginx is in
its own container, where `127.0.0.1` is nginx itself. The API is another container, found by
its name (`api`) on the shared network. The official nginx image reads any config in
`/etc/nginx/conf.d/`, so the Dockerfile simply copies it there, plus the three web files.

## Example

```bash
cd app/linkly
docker build -t linkly-web web
docker run --rm --add-host api:127.0.0.1 linkly-web nginx -t      # syntax is ok
```

(`--add-host` only gives nginx *some* address for `api` so it can check the config on its own.)

Now all five parts by hand. With `postgres` and `redis` already running on `linkly-net`:

```bash
docker build -t linkly-api api && docker build -t linkly-worker worker
APP_ENV="-e DATABASE_URL=postgresql://linkly:linkly@postgres:5432/linkly -e REDIS_URL=redis://redis:6379/0"
docker run -d --name api    --network linkly-net $APP_ENV linkly-api
docker run -d --name worker --network linkly-net $APP_ENV linkly-worker
docker run -d --name web    --network linkly-net -p 8080:8080 linkly-web
```

Open http://localhost:8080 and use it: shorten, click, refresh the count. It's the same app
as Module 0, and nothing is installed on your machine except Docker.

## Lab

- [ ] Build the web image and check its nginx config
- [ ] Run all five Linkly containers by hand on one network
- [ ] Shorten and click a link through the containerised page
- [ ] Count the docker run flags you needed and write them down

## Check yourself

1. Why does `proxy_pass http://127.0.0.1:8000` break inside the web container?

<details><summary>Answer</summary>

`127.0.0.1` is the web container itself, and nothing listens on 8000 there. The API is a
different container, reachable as `api` on the shared network.

</details>

2. The page loads but shortening fails with 502. What do you check?

<details><summary>Answer</summary>

That the `api` container is running and healthy (`docker ps`), that it's on the same network as
`web`, and that it's actually named `api`, which is what nginx asks DNS for.

</details>

3. What would you have to repeat by hand if you rebooted now?

<details><summary>Answer</summary>

Every `docker run` above, in the right order with the right flags: the same problem as Module
0, just shorter. Lesson 6 fixes that.

</details>

## Clean up

`docker rm -f web worker api postgres redis && docker network rm linkly-net && docker volume rm linkly-pg`.
Compose will create its own network and volume in lesson 6.
