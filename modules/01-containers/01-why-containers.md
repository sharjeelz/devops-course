# Why containers

> **You need:** Docker installed (see the module README) · **Time:** ~60 min · **Start from:** `checkpoint/01-containers`

## Why this matters

Look at the list you wrote at the end of Module 0. Half of it is "install the right version of X"
and "configure X before starting Y". Now imagine doing it on ten servers, or on a teammate's
laptop that already has a different Postgres. That's the "works on my machine" problem, and
it's what containers were made for: ship the program **together with** everything it needs.

## Concept

- **Image:** a read-only package of a program plus its files, libraries and default settings.
  Think of it as a class.
- **Container:** a running instance of an image, with its own writable layer on top. Think of
  it as an object: you can run many containers from one image.
- **Layers:** an image is a stack of layers, each one a set of file changes. Layers are shared
  between images and cached, which is why pulling or building the second time is fast.
- **Registry and tags:** images live in registries (Docker Hub, GitHub Container Registry). A
  tag names a version: `postgres:16-alpine` is Postgres 16 built on the small Alpine Linux.
- **Containers vs VMs:** a VM runs a whole operating system with its own kernel. A container
  is just a process on the host's kernel, fenced off with Linux features: *namespaces* (its own
  view of processes, network and files) and *cgroups* (limits on CPU and memory). So it
  starts in milliseconds and costs almost nothing extra, but every container on a host shares
  that host's kernel.

## Example

```bash
docker run -d --name redis-try -p 6379:6379 redis:7-alpine   # -d: in the background; -p host:container
docker ps                                                    # what's running
docker exec -it redis-try redis-cli ping                     # run a command inside it → PONG
docker logs redis-try                                        # its output
docker stop redis-try && docker rm redis-try                 # stop it, then delete it
```

The first `docker run` downloaded the image; run it again and it starts instantly from the cache.

Different versions side by side, with no conflict:

```bash
docker run --rm postgres:16-alpine psql --version    # psql (PostgreSQL) 16.x
docker run --rm postgres:15-alpine psql --version    # psql (PostgreSQL) 15.x
docker image history redis:7-alpine                  # the layers, newest first
```

## Lab

- [ ] Run Redis in a container and ping it
- [ ] Find the image's size and layers with docker image history
- [ ] Run two different Postgres versions side by side on different host ports
- [ ] Stop the apt-installed Redis from Module 0 and use the container instead
- [ ] Explain why the two Postgres versions didn't conflict

Hints: two Postgres servers need `-e POSTGRES_PASSWORD=x` and different host ports, e.g.
`-p 5433:5432` and `-p 5434:5432`. To free port 6379 from Module 0's Redis:
`sudo systemctl stop redis-server`.

## Check yourself

1. What's the difference between an image and a container?

<details><summary>Answer</summary>

An image is the read-only package; a container is a running (or stopped) instance of it with
its own writable layer. One image, many containers.

</details>

2. What does `-p 8080:80` mean?

<details><summary>Answer</summary>

Connections to port 8080 on your machine are forwarded to port 80 inside the container.
The left side is the host, the right side is the container.

</details>

3. Why does a container start in milliseconds when a VM takes a minute?

<details><summary>Answer</summary>

There's no operating system to boot: a container is a fenced-off process on the host's
already-running kernel.

</details>

4. You write a file inside a container, then `docker rm` it. What happens to the file?

<details><summary>Answer</summary>

It's gone with the container's writable layer. Data that must survive goes in a volume
(next lesson).

</details>

## Clean up

`docker rm -f $(docker ps -aq --filter name=redis-try)` and remove any Postgres containers you
started. If you stopped Module 0's Redis, `sudo systemctl start redis-server` brings it back.
