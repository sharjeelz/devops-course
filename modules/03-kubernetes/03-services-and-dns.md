# Services and DNS

> **You need:** Lesson 2 (Redis running in `linkly`) · **Time:** ~45 min · **Start from:** `checkpoint/03-kubernetes`

## Why this matters

Every pod gets its own IP address, and a new one each time it's replaced, which you just did on
purpose in lesson 2. The API can't keep up with that. A **Service** gives a stable name and
address in front of whichever pods match its selector, just like Compose's service names did.

## Concept

- **ClusterIP Service** (the default): a fixed virtual IP and a DNS name inside the cluster,
  spreading connections across the ready pods behind it.
- **DNS:** a Service named `redis` in namespace `linkly` is reachable as `redis` from the same
  namespace, or as `redis.linkly.svc.cluster.local` from anywhere in the cluster.
- **Only ready pods get traffic:** a pod failing its readiness probe is taken out of the Service
  until it recovers (lesson 6).
- **`kubectl port-forward`** tunnels a port from your machine to a Service or pod, for poking at
  things while debugging. It isn't how users reach an app; that's lessons 6 and 7.

## Example

`30-redis.yaml` already contains the Service. Reach it by name from a throwaway pod:

```bash
kubectl -n linkly run tmp --rm -i --restart=Never --image=redis:7-alpine -- redis-cli -h redis ping
# PONG
kubectl -n linkly run tmp --rm -i --restart=Never --image=redis:7-alpine -- redis-cli -h redis.linkly.svc.cluster.local ping
# PONG
kubectl -n linkly get svc redis                  # its ClusterIP
kubectl -n linkly get endpointslices -l kubernetes.io/service-name=redis   # the pod IPs behind it
```

(`--rm -i --restart=Never` runs one command in a temporary pod and deletes it afterwards.)

From your own machine:

```bash
kubectl -n linkly port-forward svc/redis 6379:6379     # leave it running, then in another terminal:
redis-cli -h localhost ping                             # PONG (redis-cli: sudo apt install -y redis-tools)
```

## Lab

- [ ] Reach Redis by its Service name from a temporary pod
- [ ] Resolve the Service's full DNS name
- [ ] Port-forward the Redis Service to your machine
- [ ] Delete the Redis pod and show the Service still works

## Check yourself

1. Why not just use the pod's IP address?

<details><summary>Answer</summary>

Pods are replaced all the time and get a new IP each time. The Service's name and IP stay put
and always point at whichever pods are currently ready.

</details>

2. What is `kubectl port-forward` for?

<details><summary>Answer</summary>

Debugging: reaching something inside the cluster from your machine for a moment. It runs
through your kubectl session, so it's not a way to serve users.

</details>
