# StatefulSets and storage

> **You need:** Lesson 4 · **Time:** ~60 min · **Start from:** `checkpoint/03-kubernetes`

## Why this matters

Pods are disposable, but Postgres's data is not. In Compose a named volume kept the data. In
Kubernetes the equivalent is a **PersistentVolumeClaim**, and databases run as a
**StatefulSet**, which gives each copy a stable name and its own disk that follows it around.

## Concept

- **PersistentVolume (PV):** a piece of storage in the cluster. **PersistentVolumeClaim (PVC):**
  a pod's request for storage ("1 GiB, read-write by one node"). A **StorageClass** creates PVs
  on demand. kind's is `standard`, which uses a folder on the node (`rancher.io/local-path`);
  on AWS it would create a cloud disk.
- **StatefulSet:** like a Deployment, but each pod has a stable name (`postgres-0`, `postgres-1`,
  …) and its own PVC from `volumeClaimTemplates`. Delete `postgres-0` and the replacement is
  also `postgres-0`, with the *same* disk.
- **Headless Service** (`clusterIP: None`): the name `postgres` resolves straight to the pod,
  which is what StatefulSets want.
- **`PGDATA` points at a subfolder** (`/var/lib/postgresql/data/pgdata`). Many cloud disks
  arrive with a `lost+found` folder at their root, and Postgres refuses to set up a database in
  a folder that isn't empty. kind's disks don't have it, but cloud ones in Module 8 do.

## Example

```bash
kubectl apply -f app/linkly/k8s/20-postgres.yaml
kubectl -n linkly rollout status statefulset/postgres
kubectl -n linkly get pvc,pv                      # data-postgres-0, Bound, 1Gi, class standard
```

Prove the data outlives the pod:

```bash
kubectl -n linkly exec postgres-0 -- psql -U linkly -d linkly -c "CREATE TABLE notes (t text); INSERT INTO notes VALUES ('still here');"
kubectl -n linkly delete pod postgres-0
kubectl -n linkly rollout status statefulset/postgres
kubectl -n linkly exec postgres-0 -- psql -U linkly -d linkly -tAc "SELECT t FROM notes"
# still here
```

## Lab

- [ ] Run Postgres as a StatefulSet
- [ ] Find its PersistentVolumeClaim and the volume behind it
- [ ] Write a row, delete the pod, and read the row back
- [ ] Explain what happens to the data if you delete the StatefulSet

Hint for the last one: try it. `kubectl -n linkly delete statefulset postgres`, then
`kubectl -n linkly get pvc`. The claim is still there, and re-applying the StatefulSet reattaches it.

## Check yourself

1. Deployment or StatefulSet for a database, and why?

<details><summary>Answer</summary>

StatefulSet: each replica keeps a stable name and its own persistent disk across restarts. A
Deployment's pods are interchangeable, with random names, and would share or lose storage.

</details>

2. What actually keeps the data when the pod is deleted?

<details><summary>Answer</summary>

The PersistentVolumeClaim and its volume. They're separate objects from the pod, and the new
`postgres-0` mounts the same claim.

</details>

3. What is a headless Service?

<details><summary>Answer</summary>

A Service with `clusterIP: None`: no virtual IP. Its DNS name resolves directly to the pods' own
addresses (and `postgres-0.postgres` to that specific pod).

</details>
