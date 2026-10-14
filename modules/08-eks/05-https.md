# HTTPS

> **You need:** Lesson 4, a domain name you control · **Time:** ~45 min · **Cost:** included in the ~$0.25/hour (certificates are free) · **Start from:** `checkpoint/08-eks`

## Why this matters

Without HTTPS, anyone between a user and Linkly (Wi-Fi, an ISP) can read or rewrite the traffic,
and browsers mark the site as not secure. Certificates used to be bought and renewed by hand,
yearly. Now they're free, short-lived, and renewed by software.

## Concept

- **DNS:** your name (e.g. `linkly.example.com`) must point at the load balancer: a **CNAME** to
  its DNS name (or an alias record, if your DNS is in Route 53).
- **Let's Encrypt** issues a certificate after you prove you control the name. With the
  **HTTP-01** challenge it asks for a token at `http://<name>/.well-known/acme-challenge/...`.
- **cert-manager** does the whole dance:
  - it sees the Gateway's `cert-manager.io/cluster-issuer: letsencrypt` annotation and its HTTPS
    listener for your name;
  - it adds a temporary HTTPRoute to answer the challenge on the HTTP listener (more specific than
    Linkly's redirect, so it wins);
  - it stores the certificate in the `linkly-tls` Secret, which the HTTPS listener uses;
  - it renews it about a month before it expires (90-day certificates).
- **Staging first:** Let's Encrypt's staging server has generous rate limits but untrusted
  certificates. Get everything working there, then switch the issuer to production.
- **HTTP → HTTPS:** the chart's `linkly-redirect` route answers plain HTTP with a 301 to HTTPS.

## Example

```bash
# 1. DNS: at your registrar, add a CNAME:  linkly.<your domain>  →  <the load balancer's name>
dig +short linkly.<your domain>              # should show the load balancer's addresses

# 2. Watch cert-manager work (staging issuer first)
kubectl -n linkly get certificate,certificaterequest,order,challenge
kubectl -n linkly describe certificate linkly-tls | tail -5

# 3. Switch to production: in cluster-issuer.yaml swap the server lines, then
kubectl apply -f app/linkly/eks/cluster-issuer.yaml
kubectl -n linkly delete secret linkly-tls  # cert-manager issues a new one from production
curl -sI https://linkly.<your domain>/ | head -1
curl -sI http://linkly.<your domain>/ | grep -i -e '^HTTP' -e '^location'   # 301 → https
```

**No domain?** Set `gateway.tls.enabled: false` and `gateway.hostname: ""` in
`gitops/values-eks.yaml`, and `baseUrl` to `http://<the load balancer's name>`. Linkly then runs on
plain HTTP at the load balancer's address. That's fine for the course, never for real users.

## Lab

- [ ] Point a DNS name at the load balancer
- [ ] Get a staging certificate, then a production one
- [ ] Watch a challenge come and go
- [ ] Confirm HTTP redirects to HTTPS
- [ ] Explain when cert-manager will renew the certificate

## Check yourself

1. The certificate stays "not ready" and the challenge says the token wasn't found. What do you check first?

<details><summary>Answer</summary>

That the name resolves to the load balancer (`dig`), because Let's Encrypt asks from the internet.
DNS changes can take minutes to spread, and a typo in the CNAME is common.

</details>

2. Why start with the staging server?

<details><summary>Answer</summary>

Production Let's Encrypt has strict rate limits (failed validations, certificates per name per
week). Mistakes while learning can lock you out for an hour or a week. Staging has the same flow
with much higher limits.

</details>
