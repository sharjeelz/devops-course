# Kubernetes Core

> **You need:** Module 1 (Docker); Module 2 helps but isn't required · **Time:** ~10 hours · **Start from:** `checkpoint/03-kubernetes`

Compose runs Linkly on one machine and restarts a container if it crashes. Kubernetes runs it
across many machines, keeps the number of copies you asked for, replaces anything that dies,
rolls out new versions without downtime, and gives every part a stable name. It's what most
companies run containers on. In this module you run Linkly on a real Kubernetes cluster on your
own laptop, using **kind** (Kubernetes in Docker).

## Install

- **kubectl**, the Kubernetes command line. Docker Desktop already includes it. On Linux, follow
  the official "Install kubectl on Linux" guide (apt repository or a single binary).
- **kind** creates clusters as Docker containers. Download the binary for your system from the
  [kind releases page](https://github.com/kubernetes-sigs/kind/releases) (v0.33.0), or with Go
  installed: `go install sigs.k8s.io/kind@v0.33.0`.

Check both: `kubectl version --client` and `kind version`.

## Before you start

Stop the Compose stack from Module 1, because the cluster's front door uses port 8080:

```bash
cd app/linkly && docker compose down
```

Everything in this module runs on your machine and costs nothing.

## Lessons

1. [Why Kubernetes](01-why-kubernetes.md): clusters, desired state, your first cluster
2. [Pods and Deployments](02-pods-and-deployments.md): running and self-healing containers
3. [Services and DNS](03-services-and-dns.md): stable names in front of changing pods
4. [ConfigMaps and Secrets](04-config-and-secrets.md): settings and credentials
5. [StatefulSets and storage](05-statefulsets-and-storage.md): Postgres with its own disk
6. [All of Linkly on Kubernetes](06-all-of-linkly.md): probes, limits, and the whole app
7. [The Gateway API](07-gateway-api.md): a modern front door
8. [Landscape: orchestrators](08-landscape.md): Swarm, Nomad, and ways to run Kubernetes

By the end, `checkpoint/04-packaging` holds Linkly with its Kubernetes manifests: where Module 4 starts.
