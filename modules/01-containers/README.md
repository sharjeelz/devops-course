# Containers (Docker)

> **You need:** Module 0 · **Time:** ~8 hours · **Start from:** `checkpoint/01-containers`

At the end of Module 0 you wrote down every manual step it took to run Linkly: install packages,
create a database, export variables in every terminal, start things in the right order, copy
files into nginx. This module turns that whole list into **one command**:

```bash
docker compose up -d --build --wait
```

You'll package each part of Linkly as a container image, learn how containers find each other
and keep their data, and describe the whole stack in one file.

## Install Docker

- **Windows:** install [Docker Desktop](https://www.docker.com/products/docker-desktop/). In
  *Settings → General*, keep **Use the WSL 2 based engine** on; in *Settings → Resources → WSL
  integration*, turn it on for your Ubuntu. Then `docker` works inside your Ubuntu terminal.
- **Linux or a VM:** `sudo apt install -y docker.io docker-compose-v2 docker-buildx && sudo usermod -aG docker $USER`,
  then log out and back in (so you don't need `sudo` for every `docker` command).

Check it: `docker run --rm hello-world` prints "Hello from Docker!".

## Before you start

Module 0 installed nginx, Redis and Postgres as services that start with the machine, and they
hold the ports this module uses (8080, 6379, 5432). Stop them and keep them from starting again:

```bash
sudo systemctl disable --now nginx redis-server postgresql
```

(`sudo systemctl enable --now ...` brings them back if you ever want Module 0's setup again.)

## Lessons

1. [Why containers](01-why-containers.md): images, containers, and what problem they solve
2. [Networks and volumes](02-networks-and-volumes.md): how containers find each other and keep data
3. [Your first Dockerfile](03-your-first-dockerfile.md): Linkly's API as an image
4. [Small, safe images](04-small-safe-images.md): multi-stage builds, tests in the image, no root
5. [The web front door in a container](05-web-in-a-container.md): nginx, and all five parts by hand
6. [One command: Docker Compose](06-compose.md): the whole stack in one file
7. [Landscape: beyond Docker](07-landscape.md): OCI, containerd, Podman, and where Docker fits

By the end, `checkpoint/02-ci` holds Linkly with its Dockerfiles and Compose file: where Module 2 starts.
