# Linkly on EC2

> **You need:** Lesson 3 (the instance running, `PUBLIC_IP` set), your GHCR images from Module 2 · **Time:** ~60 min · **Cost:** the instance from lesson 3, about $0.02 per hour · **Start from:** `checkpoint/06-aws`

## Why this matters

This is Module 0 again, on a cloud server. You'll put the whole of Linkly on one EC2 instance,
by hand, and pay attention to every step: which ones you'd forget, which ones break if the
server is replaced, which ones nobody could repeat from your terminal history. Module 7 replaces
all of it with code.

## Concept

- **Pull, don't build:** the server doesn't build anything. It pulls the images your Module 2
  pipeline built, tested and published, so what runs is exactly what CI checked.
- **`compose.ghcr.yaml`** layers on top of `compose.yaml` and swaps each `build:` for
  `image: ${LINKLY_IMAGES}/linkly-<svc>:${LINKLY_TAG}`. It refuses to start without both values.
- **`LINKLY_BASE_URL`** makes short links point at the server's address instead of `localhost`.
- **`install-docker.sh`:** Amazon Linux 2023 has Docker but not the Compose plugin. The script
  installs Docker and a pinned Compose release, and only after checking it against its published checksum.
- **What's still missing,** on purpose: no HTTPS, no backups (next lesson), one machine (if it
  dies, Linkly dies), no record of how it was set up except your memory.

## Example

From your laptop, copy the three files the server needs:

```bash
scp -i linkly-course.pem app/linkly/aws/install-docker.sh app/linkly/compose.yaml app/linkly/compose.ghcr.yaml \
  ec2-user@"$PUBLIC_IP":
ssh -i linkly-course.pem ec2-user@"$PUBLIC_IP"
```

On the server:

```bash
sudo bash install-docker.sh                # Docker + Compose plugin (checksum-verified)
exit                                       # log out and back in, so your user can use docker
```

```bash
ssh -i linkly-course.pem ec2-user@"$PUBLIC_IP"
export LINKLY_IMAGES=ghcr.io/<you> LINKLY_TAG=sha-<a build from your packages page>
export LINKLY_BASE_URL=http://<the PUBLIC_IP>:8080
docker compose -f compose.yaml -f compose.ghcr.yaml up -d --wait
docker compose -f compose.yaml -f compose.ghcr.yaml ps
```

Open `http://<PUBLIC_IP>:8080` in your browser (allowed from your IP only), shorten a link, and
click it: Linkly, in the cloud.

## Lab

- [ ] Install Docker and Compose on the instance
- [ ] Run Linkly from your own GHCR images
- [ ] Use Linkly from your browser through the public IP
- [ ] Write down every manual step and what would break if the server were replaced

## Check yourself

1. Why does the server pull images instead of building them?

<details><summary>Answer</summary>

So it runs exactly what CI tested and published: the same bytes, traceable to a commit. Building
on the server would make an untested image with whatever versions were current that minute.

</details>

2. The instance is terminated by mistake. What do you lose, and what would you have to redo?

<details><summary>Answer</summary>

The database (links and counts) and every setup step: installing Docker and Compose, copying
files, the environment variables, starting the stack. That's the case for backups (lesson 5) and
infrastructure as code (Module 7).

</details>

## Clean up

`docker compose -f compose.yaml -f compose.ghcr.yaml down` stops Linkly. The instance keeps
costing money until it's terminated (lesson 7). Keep it if you're doing lesson 5 next.
