# One command: Docker Compose

> **You need:** Lessons 1–5 · **Time:** ~75 min · **Start from:** `checkpoint/01-containers`

## Why this matters

Count the flags from lesson 5: a network, a volume, five names, environment variables twice,
ports, and an order to start things in. That's Module 0's list again, just shorter. Docker
Compose lets you **declare** all of it in one file and bring the whole stack up, or down, with
one command.

## Concept

- **Services, networks, volumes** declared once in `compose.yaml`. Compose creates a network
  for the project automatically, and every service can reach the others by service name.
- **`depends_on` with `condition: service_healthy`:** start the API only when Postgres and
  Redis pass their healthchecks, and the worker and web only when the API does.
- **Restart policies:** `restart: unless-stopped` brings a crashed container back, and brings
  the stack back after a reboot.
- **Variables:** `${LINKLY_PORT:-8080}` means "the LINKLY_PORT environment variable, or 8080".
- **YAML anchors:** `x-app-env: &app-env` defines the shared database and Redis settings once;
  `<<: *app-env` reuses them.

## Example

Read `app/linkly/compose.yaml` top to bottom first: every line maps to something you did by
hand in lesson 5. Then:

```bash
cd app/linkly
docker compose up -d --build --wait     # build, start, and wait until every service is healthy
docker compose ps                       # five services, the API and web "(healthy)"
docker compose logs -f worker           # leave this running while you click links (Ctrl+C to stop)
```

Open http://localhost:8080. If 8080 is taken on your machine: `LINKLY_PORT=9090 docker compose up -d --build --wait`.

Data survives:

```bash
docker compose down        # containers and network removed; the pgdata volume stays
docker compose up -d --wait
# your short links still work
```

And the stack checks itself. `smoke-test.sh` builds a throwaway copy and uses it like a person
would: it shortens, redirects and counts, refuses bad input, restarts with the data kept, then
deletes everything:

```bash
./smoke-test.sh            # ... SMOKE TEST PASSED
```

## Lab

- [ ] Start the whole stack with one command
- [ ] Watch the worker's log while clicking a link
- [ ] Stop Postgres with docker compose stop and watch the worker wait instead of crashing
- [ ] Restart the stack and show your links survived
- [ ] Run the smoke test and read what each section checks
- [ ] Compare this with your Module 0 list of manual steps

Hint for the Postgres item: `docker compose stop postgres`, click a link (it still redirects:
the API finds it in the Redis cache), and within about 10 seconds the worker log says
`postgres unavailable ... retrying in 2 s`. Then `docker compose start postgres`: the click
was put back on the queue, so it still gets counted.

## Check yourself

1. What does `--wait` wait for?

<details><summary>Answer</summary>

Until every service is running, and healthy if it has a healthcheck. The command fails if one
doesn't get there.

</details>

2. What's the difference between `docker compose down` and `docker compose down -v`?

<details><summary>Answer</summary>

`down` removes the containers and network but keeps named volumes, so your data stays. `-v`
also deletes the volumes, and with them all your links.

</details>

3. Why does the worker wait for the API's health rather than just for Postgres?

<details><summary>Answer</summary>

The API creates the `links` table when it starts. Waiting until the API is healthy means the
table exists before the worker tries to update it.

</details>

## Clean up

`docker compose down -v` deletes the stack and its data. Nothing here cost money.
