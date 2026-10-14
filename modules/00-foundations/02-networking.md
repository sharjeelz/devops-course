# Networking for DevOps

> **You need:** Lesson 1 · **Time:** ~75 min

## Why this matters

"It works on my machine but not from yours" is almost always one of three things: the program
is listening on the wrong address or port, a name doesn't resolve to the address you think,
or something in between (a firewall, a proxy) is in the way. Knowing how to check each one
turns a day of guessing into five minutes.

## Concept

- **IP addresses and ports.** An IP finds the machine, a port finds the program on it. A web
  server is usually on 80 (HTTP) or 443 (HTTPS); Postgres on 5432; Redis on 6379.
- **`127.0.0.1` vs `0.0.0.0`.** A program listening on `127.0.0.1` (localhost) only accepts
  connections from the same machine. On `0.0.0.0` it accepts them on every network interface.
  Databases should usually be the first kind; public web servers the second.
- **DNS.** Turns names into addresses. An **A** record maps a name to an IPv4 address; a
  **CNAME** points one name at another name.
- **HTTP.** A request (method, path, headers, maybe a body) gets a response (status code,
  headers, body). Status codes by family: `2xx` worked, `3xx` go elsewhere, `4xx` you asked
  wrong, `5xx` the server failed.
- **TLS.** The "S" in HTTPS: it encrypts the connection and proves the server owns the name,
  using a certificate.
- **Reverse proxy.** A server (nginx here) that receives requests and passes them on to the
  right program behind it. In Lesson 4, nginx serves Linkly's page and forwards `/api/` to the API.

## Example

```bash
ip a                            # your machine's addresses
ss -tlnp                        # every TCP port something is listening on, and which program
dig +short github.com           # what a name resolves to (install with: sudo apt install -y dnsutils)
curl -v https://example.com     # a full HTTP conversation: request lines start with >, response with <
```

Watch the difference between listening addresses:

```bash
python3 -m http.server 9000 --bind 0.0.0.0     # terminal 1: reachable from outside
curl -I localhost:9000                         # terminal 2: HTTP/1.0 200 OK
```

Now open `http://localhost:9000` in your Windows browser: WSL2 forwards it. Stop the server
(Ctrl+C) and start it with `--bind 127.0.0.1`, then try again from Windows.

## Lab

- [ ] List every port listening on your machine and name the program behind each
- [ ] Resolve `github.com` and say which IP your machine would use
- [ ] Start a web server on port 9000 and reach it from your Windows browser
- [ ] Make the same server unreachable from outside by binding it to 127.0.0.1
- [ ] Read a `curl -v` output and point at the status line, the headers and the body

## Check yourself

1. What does each of these tell you: `301`, `404`, `502`?

<details><summary>Answer</summary>

`301`: the thing moved permanently, so follow the `Location` header. `404`: the server is fine,
but nothing is at that path. `502 Bad Gateway`: a proxy (like nginx) couldn't get an answer
from the program behind it, which is often down or on a different port.

</details>

2. Why put a reverse proxy in front of an app at all?

<details><summary>Answer</summary>

One public entry point that can serve static files, terminate TLS, route paths to different
programs and add things like rate limits, while the apps stay private on localhost.

</details>

3. A program fails to start with `address already in use`. What happened, and how do you find out who?

<details><summary>Answer</summary>

Another process is already listening on that port. `sudo ss -tlnp | grep :<port>` shows its
name and PID.

</details>
