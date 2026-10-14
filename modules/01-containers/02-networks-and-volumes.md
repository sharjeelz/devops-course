# Networks and volumes

> **You need:** Lesson 1 · **Time:** ~60 min · **Start from:** `checkpoint/01-containers`

## Why this matters

Linkly is five parts that talk to each other, and Postgres holds data that must outlive any
container. So before packaging Linkly, two questions: how does the API container find the
Postgres container, and where does Postgres keep its data when its container is replaced?

## Concept

- **User-defined networks.** Containers on the same user-defined bridge network can reach
  each other **by container name**: Docker runs a small DNS server for them. (The default
  network doesn't do this, which is why you always create your own.)
- **`localhost` inside a container is that container.** Not your machine, and not the
  container next to it. This trips up everyone once: the API can't reach Postgres at
  `localhost:5432` any more; it's at `postgres:5432`.
- **Volumes.** A *named volume* is storage Docker manages, mounted into a container at a
  path. Delete the container and the volume stays. A *bind mount* maps a folder from your
  machine into the container: handy for development, but the data lives in your folder.

## Example

```bash
docker network create linkly-net
docker run -d --name postgres --network linkly-net \
  -e POSTGRES_USER=linkly -e POSTGRES_PASSWORD=linkly -e POSTGRES_DB=linkly \
  -v linkly-pg:/var/lib/postgresql/data postgres:16-alpine
docker run --rm --network linkly-net postgres:16-alpine pg_isready -h postgres
# postgres:5432 - accepting connections      ← found by name
```

Now prove the data outlives the container:

```bash
docker exec postgres psql -U linkly -d linkly -c "CREATE TABLE notes (t text); INSERT INTO notes VALUES ('still here');"
docker rm -f postgres                                   # the container is gone...
docker run -d --name postgres --network linkly-net \
  -e POSTGRES_USER=linkly -e POSTGRES_PASSWORD=linkly -e POSTGRES_DB=linkly \
  -v linkly-pg:/var/lib/postgresql/data postgres:16-alpine
sleep 3; docker exec postgres psql -U linkly -d linkly -tc "SELECT t FROM notes;"
#  still here                                           # ...the data isn't
```

And see `localhost` fail between containers:

```bash
docker run -d --name redis --network linkly-net redis:7-alpine
docker run --rm --network linkly-net redis:7-alpine redis-cli -h localhost ping   # Could not connect
docker run --rm --network linkly-net redis:7-alpine redis-cli -h redis ping       # PONG
```

Keep `linkly-net`, `postgres`, `redis` and the `linkly-pg` volume: lesson 3 uses them.

## Lab

- [ ] Create a network and reach one container from another by name
- [ ] Show that localhost inside a container does not reach the other container
- [ ] Put Postgres data on a named volume, delete the container, and get the data back
- [ ] Use a bind mount to serve a folder from your machine with nginx:1.27-alpine
- [ ] List the volumes and networks you created

Hint for the bind mount: `docker run --rm -p 8081:80 -v "$PWD/site:/usr/share/nginx/html:ro" nginx:1.27-alpine`
with an `index.html` in `./site`, then open http://localhost:8081.

## Check yourself

1. Why can't the API container reach Postgres at `localhost:5432`?

<details><summary>Answer</summary>

Inside a container, `localhost` is the container itself, and nothing in the API container is
listening on 5432. Postgres is another container, reachable by its name on the shared network.

</details>

2. Named volume or bind mount: which would you use for Postgres data, and which for live-editing your HTML?

<details><summary>Answer</summary>

A named volume for Postgres (Docker manages it, and it survives the container). A bind mount
for HTML you're editing, so changes on your machine show up in the container at once.

</details>

3. What would `docker volume prune` delete?

<details><summary>Answer</summary>

Volumes not used by any container. Including your Postgres data if its container is removed, so
be careful.

</details>

## Clean up

Later, when you're done with lesson 5: `docker rm -f postgres redis && docker network rm linkly-net && docker volume rm linkly-pg`.
