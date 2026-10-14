# Why Kubernetes

> **You need:** kind and kubectl installed (module README) · **Time:** ~60 min · **Start from:** `checkpoint/03-kubernetes`

## Why this matters

Compose is great on one machine. But one machine is a single point of failure, it can only get
so big, and Compose won't move your containers somewhere else if the machine dies. Teams that
run many services across many machines need something that keeps everything running *as
described*, all the time, without a person watching. That's Kubernetes.

## Concept

- **Cluster:** a set of machines (**nodes**) that run your containers, plus a **control plane**
  that decides what runs where.
- **Desired state:** you don't say "start this container". You say "there should be 2 copies
  of the API running", and store that in the cluster.
- **Reconciliation:** controllers in the control plane compare *desired* with *actual* state,
  over and over, and act on any difference. If a copy dies, they start another. If a node
  disappears, its work moves elsewhere.
- **The API server** is the front door of the control plane. Everything (you, kubectl, other
  controllers) talks to it, and it stores state in **etcd**.
- **kubectl** is a client for the API server. It reads `~/.kube/config` to know which cluster
  (**context**) to talk to.

```
 you ─ kubectl ─▶ API server ─▶ etcd (desired state)
                      ▲
     controllers ─────┘  watch, compare, fix
     scheduler: picks a node for each new pod
     kubelet (on every node): runs the pod's containers
```

## Example

From the repo root:

```bash
kind create cluster --name linkly --config app/linkly/kind-config.yaml
kubectl get nodes                      # one node: linkly-control-plane, Ready
kubectl get pods -A                    # everything running, in every namespace
kubectl config current-context         # kind-linkly
```

The `kube-system` namespace holds the cluster's own parts as pods: `etcd`, `kube-apiserver`,
`kube-scheduler`, `kube-controller-manager`, `coredns` (the cluster's DNS) and `kindnet` (its network).

`app/linkly/kind-config.yaml` asks kind to forward your machine's port 8080 into the cluster;
lesson 6 uses it.

## Lab

- [ ] Create the cluster with the repo's kind config
- [ ] List the system pods and say what three of them do
- [ ] Find your current kubectl context
- [ ] Delete the cluster and create it again

Hint: `kind delete cluster --name linkly` deletes it in seconds. That's the point of a local
cluster: it's disposable.

## Check yourself

1. What does "reconciliation" mean in Kubernetes?

<details><summary>Answer</summary>

Controllers keep comparing the desired state you stored with what's actually running, and take
action (start, stop, replace) until they match. It never stops, which is why things heal themselves.

</details>

2. What's the difference between the control plane and a node?

<details><summary>Answer</summary>

The control plane decides and records (API server, etcd, scheduler, controllers). Nodes do the
work: their kubelet runs the containers. In kind, one container plays both roles.

</details>

3. How does kubectl know which cluster to talk to?

<details><summary>Answer</summary>

From the current context in `~/.kube/config`. `kubectl config get-contexts` lists them, and
`kubectl config use-context <name>` switches.

</details>
