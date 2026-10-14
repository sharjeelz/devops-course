# Run Linkly by hand

> **You need:** Lessons 1–3, your fork cloned in your Linux home · **Time:** ~2 hours

## Why this matters

Before you automate anything, feel what you're automating. In this lesson you'll install and
start every piece of Linkly yourself, in the right order, with the right settings. It works,
and it's fragile, slow and easy to get wrong. Every annoyance you hit here is a problem a later
module solves: Module 1 turns this whole lesson into one command.

## Concept

Linkly has five parts. Each one needs a runtime, some configuration, a port, and the parts it depends on:

```
browser → nginx :8080 ─┬─ static files (web/)
                       └─ /api/, /r/ → api :8000 ─┬─ postgres (links, click counts)
                                                  └─ redis (cache, "clicks" queue) ← worker → postgres
```

| Part | Runtime | Needs | Port |
|---|---|---|---|
| postgres | Postgres 16 | a database and a user | 5432 |
| redis | Redis | nothing | 6379 |
| api | Python 3 + its packages | `DATABASE_URL`, `REDIS_URL`, `BASE_URL` | 8000 |
| worker | Python 3 + its packages | `DATABASE_URL`, `REDIS_URL` | none |
| nginx | nginx | the web files, and the API running | 8080 |

So the order is: databases first, then the API and worker, then nginx in front.

## Example

**1. Install the system pieces** (Ubuntu 24.04):

```bash
sudo apt update
sudo apt install -y python3-venv postgresql redis-server nginx
systemctl status postgresql redis-server nginx --no-pager | grep -E "●|Active"
```

All three show `active (running)`: apt starts services for you.

**2. Create the database and its user:**

```bash
sudo -u postgres psql -c "CREATE USER linkly WITH PASSWORD 'linkly';" -c "CREATE DATABASE linkly OWNER linkly;"
```

Expected: `CREATE ROLE` then `CREATE DATABASE`.

**3. Configure it** for this terminal session (you'll need these in every terminal you open):

```bash
export DATABASE_URL=postgresql://linkly:linkly@localhost:5432/linkly
export REDIS_URL=redis://localhost:6379/0
export BASE_URL=http://localhost:8080
```

**4. Start the API** (terminal 1):

```bash
cd ~/devops-course/app/linkly/api
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
.venv/bin/uvicorn linkly_api.main:app_from_env --factory --port 8000
```

Expected: `Uvicorn running on http://127.0.0.1:8000`. In another terminal, check
`curl localhost:8000/healthz`, which should print `{"status":"ok"}`.

**5. Start the worker** (terminal 2; export the three variables again first):

```bash
cd ~/devops-course/app/linkly/worker
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
.venv/bin/python -m linkly_worker.main
```

Expected: `INFO:linkly-worker:worker started`.

**6. Put the page behind nginx** (terminal 3):

```bash
cd ~/devops-course/app/linkly/web
sudo mkdir -p /var/www/linkly
sudo cp index.html app.js style.css /var/www/linkly/
sudo cp nginx.conf /etc/nginx/sites-available/linkly
sudo ln -sf /etc/nginx/sites-available/linkly /etc/nginx/sites-enabled/linkly
sudo nginx -t && sudo systemctl reload nginx
```

Expected: `syntax is ok` and `test is successful`.

**7. Use it.** (Don't be surprised that `https://example.com` comes back as `https://example.com/`:
the API stores links in their standard form.) Open http://localhost:8080 in your browser, shorten a link, open the short link,
then press **Refresh**: the click count goes up within a few seconds (that's the worker at work).
Or from the terminal:

```bash
curl -s -X POST localhost:8080/api/links -H 'content-type: application/json' -d '{"url":"https://example.com"}'
curl -s -o /dev/null -w '%{http_code} %{redirect_url}\n' localhost:8080/r/<code>   # 307 https://example.com/
curl -s localhost:8080/api/links/<code>           # "clicks":1 after a few seconds
```

> **Common problems**
> - **`502 Bad Gateway` from nginx:** the API isn't running, or not on port 8000. Check terminal 1.
> - **`password authentication failed for user "linkly"`:** step 2 didn't run, or `DATABASE_URL` has a typo.
> - **The API exits with `KeyError: 'DATABASE_URL'`:** you opened a new terminal and didn't export the variables.
> - **`address already in use`:** something else has that port; `sudo ss -tlnp | grep :8000`.
> - **Weird `\r` errors from files copied out of Windows:** clone the repo inside Linux (`~`), not under `/mnt/c`.

## Lab

- [ ] On Windows, install WSL2 Ubuntu first (`wsl --install -d Ubuntu-24.04`)
- [ ] Install Postgres, Redis, nginx and Python's venv with apt
- [ ] Create the `linkly` database and user
- [ ] Start the API on port 8000 and see `/healthz` answer
- [ ] Start the worker
- [ ] Put the web page behind nginx on port 8080
- [ ] Shorten a link in the browser, click it, and see the click count go up
- [ ] Stop Redis (`sudo systemctl stop redis-server`), click your link again, and explain what still works and what doesn't
- [ ] Write down every manual step you took and how long it took

That last list is the point of this lesson. Keep it: Module 1 replaces it with one command.

## Check yourself

1. The server reboots. What's still running afterwards, and what isn't?

<details><summary>Answer</summary>

Postgres, Redis and nginx come back, because apt registered them as systemd services. The API
and worker don't: they were just programs started in your terminals. You'd have to log in,
export the variables and start them again, in the right order.

</details>

2. With Redis stopped, short links still redirect. Why, and what's lost?

<details><summary>Answer</summary>

When Redis is unavailable the API reads the link from Postgres instead of the cache, so
redirects keep working. But it can't queue the click, so those clicks are never counted, and
the worker just logs warnings until Redis is back.

</details>

3. How would you run two copies of the API to handle more traffic?

<details><summary>Answer</summary>

Start a second one on another port (say 8001) and list both in nginx with an `upstream` block so
it spreads requests between them. Doable by hand, and painful, which is what Kubernetes in
Module 3 is for.

</details>

## Stretch

Write systemd units for the API and the worker (`/etc/systemd/system/linkly-api.service` with
`Environment=` lines for the three variables) so they start on boot, restart when they crash,
and log to `journalctl`.

## Clean up

Nothing here costs money. To stop everything: Ctrl+C in the API and worker terminals, then
`sudo systemctl stop nginx redis-server postgresql`. Keep the installed packages: Module 1
compares this setup with containers.
