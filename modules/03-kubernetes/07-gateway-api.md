# The Gateway API

> **You need:** Lesson 6 (Linkly running in the `linkly` cluster) · **Time:** ~60 min · **Start from:** `checkpoint/03-kubernetes`

## Why this matters

A NodePort is fine on a laptop, but real clusters put one proper front door in front of many
apps: routing by hostname and path, TLS certificates, traffic splitting. For years that was
**Ingress**, most often with the ingress-nginx controller. ingress-nginx was retired in March
2026, and the Kubernetes project's answer for new work is the **Gateway API**.

## Concept

- **Ingress (the old way):** one object mixing who runs the load balancer with each app's
  routes, and many features only available through controller-specific annotations.
- **Gateway API** splits the job by role:
  - **GatewayClass:** *which* implementation runs gateways (set up once, by the platform team).
  - **Gateway:** an actual entry point, with listeners on ports (owned by the cluster operator).
  - **HTTPRoute:** an app's routing rules: hostnames, paths, which Service gets the traffic
    (owned by the app team, attached to a Gateway with `parentRefs`).
- **Implementations:** the API is a standard, and several projects implement it: Envoy Gateway
  (used here), NGINX Gateway Fabric, Istio, Cilium, Traefik and others. Switching between them
  means changing the GatewayClass, not your routes.
- **Addresses:** a Gateway gets a Service of type LoadBalancer. On a cloud, the cloud gives it
  a public address. kind has no cloud, so its address stays `<pending>` and the Gateway reports
  `Programmed=False (AddressNotAssigned)`. Routing still works; we reach it with port-forward.

## Example

Install Envoy Gateway (its CRDs, controller and the Gateway API types):

```bash
kubectl apply --server-side -f https://github.com/envoyproxy/gateway/releases/download/v1.9.2/install.yaml
kubectl -n envoy-gateway-system wait --for=condition=Available deployment/envoy-gateway --timeout=300s
```

Apply Linkly's GatewayClass, Gateway and HTTPRoute (`app/linkly/k8s/gateway/gateway.yaml`):

```bash
kubectl apply -f app/linkly/k8s/gateway/gateway.yaml
kubectl -n linkly wait --for=condition=Accepted gateway/linkly --timeout=120s
kubectl -n linkly get gateway,httproute
```

Find the Envoy Service created for the Gateway, and reach Linkly through it:

```bash
svc=$(kubectl -n envoy-gateway-system get svc -l gateway.envoyproxy.io/owning-gateway-name=linkly -o jsonpath='{.items[0].metadata.name}')
kubectl -n envoy-gateway-system get svc "$svc"            # TYPE LoadBalancer, EXTERNAL-IP <pending>
kubectl -n envoy-gateway-system port-forward "svc/$svc" 8081:80
```

Open http://localhost:8081: the same Linkly, now through the Gateway API. The request goes
Envoy → HTTPRoute → `web` Service → nginx → `api`.

## Lab

- [ ] Install Envoy Gateway in your cluster
- [ ] Apply Linkly's Gateway and HTTPRoute
- [ ] Reach Linkly through the gateway on port 8081
- [ ] Explain which team would own each of the three Gateway API resources

Hint: `kubectl -n linkly get gateway linkly -o yaml` shows the `Accepted` and `Programmed`
conditions and why Programmed is false on kind.

## Check yourself

1. What does the Gateway API fix compared with Ingress?

<details><summary>Answer</summary>

It separates roles (infrastructure, cluster operator, app team) into different objects, and it
puts features like header matching and traffic splitting in the standard instead of in
controller-specific annotations, so routes move between implementations.

</details>

2. What does an HTTPRoute attach to, and how?

<details><summary>Answer</summary>

To a Gateway, named in its `parentRefs`. The Gateway must allow routes from that namespace (by
default, its own).

</details>

3. Why is the Gateway's address `<pending>` on kind but not on AWS?

<details><summary>Answer</summary>

A LoadBalancer Service needs something to create a load balancer. A cloud provider does this
automatically; kind doesn't have one (tools like cloud-provider-kind can add it).

</details>

## Clean up

Ctrl+C the port-forward. `kind delete cluster --name linkly` removes everything from this module.
