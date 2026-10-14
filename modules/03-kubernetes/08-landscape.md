# Landscape: orchestrators

> **You need:** Lessons 1–7 · **Time:** ~40 min · **Start from:** `checkpoint/03-kubernetes`

## Why this matters

Kubernetes won, but not everyone needs it, and "Kubernetes" itself comes in many shapes: from
a single binary on a Raspberry Pi to a managed service run by AWS. Knowing the options helps you
pick the right one, and avoid using a cluster where a single server would do.

## Concept

- **Docker Swarm:** built into Docker (`docker swarm init`), and uses Compose-style files
  (`docker stack deploy`). Very simple, but it has seen little development for years and few
  new projects choose it.
- **HashiCorp Nomad:** one small binary that schedules containers *and* plain programs and VMs.
  Simpler to run than Kubernetes; popular where teams already use Consul and Vault.
- **Managed Kubernetes:** EKS (AWS, Module 8), GKE (Google), AKS (Azure). The provider runs the
  control plane, upgrades and etcd; you run your workloads (and often the nodes).
- **Local and small clusters:** kind (what we use: clusters as containers, great for CI),
  minikube, k3d (k3s in Docker), Docker Desktop's built-in Kubernetes. **k3s** is a lightweight
  distribution often used on edge devices and small servers.
- **The CNCF** (Cloud Native Computing Foundation) hosts Kubernetes and much of the ecosystem
  around it, including containerd, Envoy, Prometheus and Argo.

## Example

```bash
kind get clusters               # the kind clusters on your machine
kubectl config get-contexts     # every cluster kubectl knows
```

For comparison only (not run): the same Redis in a Swarm stack file looks almost exactly like
Compose:

```yaml
services:
  redis:
    image: redis:7-alpine
    deploy:
      replicas: 1
```

## Lab

- [ ] Name two ways to run Kubernetes on your laptop
- [ ] Explain one reason a team might pick Nomad over Kubernetes
- [ ] Compare a Swarm stack file with our Compose file

## Check yourself

1. What does "managed Kubernetes" take off your hands, and what doesn't it?

<details><summary>Answer</summary>

It runs the control plane for you: API server, etcd, upgrades, high availability. You still
own your workloads, their configuration and security, and usually the nodes' size and count.

</details>

2. When might Kubernetes be the wrong choice?

<details><summary>Answer</summary>

For one small app on one server, a team with no capacity to learn and operate it, or a workload
a managed platform (a PaaS, serverless) already covers. Compose on a single VM is often enough.

</details>
