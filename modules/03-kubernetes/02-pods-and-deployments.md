# Pods and Deployments

> **You need:** Lesson 1, with the `linkly` cluster running · **Time:** ~60 min · **Start from:** `checkpoint/03-kubernetes`

## Why this matters

Containers in Kubernetes don't run on their own: they run inside **pods**, and pods are
almost always managed by a **Deployment** that keeps the right number of them alive. Seeing a
pod you deleted come straight back is the moment Kubernetes clicks.

## Concept

- **Pod:** the smallest thing Kubernetes runs, one or more containers that share a network
  address and can share files. Pods are disposable: they're replaced, never repaired.
- **Labels and selectors:** pods carry labels (`app: redis`); other objects find them with a
  selector (`matchLabels: app: redis`). That's how everything is wired together.
- **Deployment:** "keep N pods like this template running". It manages a **ReplicaSet**, which
  creates and deletes the pods, and it handles rolling updates when the template changes.
- **Namespace:** a folder for objects. Linkly lives in `linkly`.

## Example

```bash
kubectl apply -f app/linkly/k8s/00-namespace.yaml -f app/linkly/k8s/30-redis.yaml
kubectl -n linkly get deploy,pods -o wide
kubectl -n linkly describe pod -l app=redis       # events at the bottom: scheduled, pulled, started
kubectl -n linkly logs deploy/redis               # Redis's own output
```

Now delete the pod and watch:

```bash
kubectl -n linkly delete pod -l app=redis --wait=false
kubectl -n linkly get pods -l app=redis           # a new pod with a new name, already Running
```

Scale it:

```bash
kubectl -n linkly scale deploy/redis --replicas=3
kubectl -n linkly get pods -l app=redis           # three pods
kubectl -n linkly scale deploy/redis --replicas=1
```

(Three Redis servers that don't share data isn't useful; it just shows the mechanism. The
manifest says `replicas: 1`, and the next `kubectl apply` puts it back.)

## Lab

- [ ] Deploy Redis and find its pod
- [ ] Read the pod's events with describe
- [ ] Delete the pod and watch a replacement appear
- [ ] Scale Redis to three replicas and back
- [ ] Explain what the Deployment's selector connects

## Check yourself

1. Pod or Deployment: what's the difference?

<details><summary>Answer</summary>

A pod is one running instance. A Deployment is the instruction "keep N pods from this template
running", and it creates and replaces pods to make that true.

</details>

2. Why do you almost never create pods directly?

<details><summary>Answer</summary>

A bare pod that dies stays dead. Nothing recreates it, moves it off a failed node, or rolls
out a new version. A Deployment does all of that.

</details>

3. What does the label selector do?

<details><summary>Answer</summary>

It says which pods belong to an object: the Deployment counts and manages pods with matching
labels, and (next lesson) a Service sends traffic to them.

</details>
