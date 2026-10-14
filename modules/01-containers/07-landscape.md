# Landscape: beyond Docker

> **You need:** Lessons 1–6 · **Time:** ~40 min · **Start from:** `checkpoint/01-containers`

## Why this matters

"Docker" means several different things: a company, a desktop app, a command-line tool, a
daemon, and an image format. In production you'll meet clusters that run containers without
Docker Engine at all, and teams that use Podman instead. Knowing the layers underneath means
none of that is confusing.

## Concept

**How we got here, briefly:**

- **2008:** Linux gains the building blocks (namespaces, cgroups); LXC uses them to run "containers".
- **2013:** Docker makes it easy, with the Dockerfile, layered images and a registry, and containers take off.
- **2015:** the **Open Container Initiative (OCI)** standardises the image format and how a runtime runs one, so images aren't tied to one tool.
- **2017:** Docker splits out **containerd** (manages images and containers) and donates it to the CNCF. Underneath it, **runc** actually starts the process.

**The layers today:**

```
docker CLI → Docker Engine (dockerd) → containerd → runc → your process
                         Kubernetes → containerd or CRI-O → runc → your process
```

- **OCI images** are the common currency: an image built with Docker runs under Podman,
  containerd or Kubernetes unchanged.
- **Kubernetes** talks to containerd or CRI-O directly. When it removed "dockershim" in v1.24,
  it stopped using Docker *Engine*; Docker-built images kept working, because they're OCI.
- **Podman** is a Docker-compatible CLI without a central daemon. It runs rootless by default
  and has `podman compose`. Popular on Red Hat systems and where a root daemon is unwelcome.
- **BuildKit and buildx** are Docker's modern builder; `buildx` builds images for several CPU
  types (amd64, arm64) at once.
- **Docker Desktop** is free for personal use, education and small companies, but larger
  companies need a paid subscription. That's one reason some teams standardise on Podman or
  Rancher Desktop.

## Example

```bash
docker info | grep -iE "runtime|containerd"     # Default Runtime: runc, and the containerd version
docker buildx ls                                 # your builders and the platforms they support
```

Optional, on Linux:

```bash
sudo apt install -y podman
podman run --rm docker.io/library/redis:7-alpine redis-server --version
```

## Lab

- [ ] Find which runtime your Docker Engine uses
- [ ] Explain what an OCI image is in two sentences
- [ ] Run one Linkly image with Podman (optional)
- [ ] Name one reason a team might pick Podman over Docker

## Check yourself

1. Did Kubernetes stop supporting Docker images?

<details><summary>Answer</summary>

No. It removed dockershim, its adapter for Docker *Engine*. Images built with Docker are OCI
images and run on Kubernetes exactly as before.

</details>

2. What's the difference between containerd and runc?

<details><summary>Answer</summary>

containerd manages the lifecycle (pull images, store them, create and supervise containers);
runc is the small low-level tool that actually creates the namespaces and cgroups and starts the process.

</details>

3. Your company is large and asks whether everyone can use Docker Desktop for free. What do you check?

<details><summary>Answer</summary>

Docker's current subscription terms: Docker Desktop needs a paid plan above a size and revenue
threshold. Alternatives include Docker Engine on Linux, Podman or Rancher Desktop.

</details>
