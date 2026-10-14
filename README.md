# DevOps, Layer by Layer

A free, self-paced DevOps and Cloud course for people who already know their way around a
terminal: developers, IT support, sysadmins. Instead of thirteen separate topics, you build
**one app, Linkly**, and every module adds one layer to it. Your lab in one module is where the
next one starts.

## The modules

| # | Module | What you add to Linkly |
|---|---|---|
| 0 | Foundations Check | Linux, networking and Git refreshers; run Linkly by hand on bare Linux and feel the pain |
| 1 | Containers (Docker) | A Dockerfile per service, multi-stage builds, Compose for the whole stack, volumes |
| 2 | CI with GitHub Actions | Lint, test, build images, push to GHCR, versioning |
| 3 | Kubernetes Core | Deployments, Services, ConfigMaps/Secrets, a StatefulSet for Postgres, Ingress/Gateway API on a local kind cluster |
| 4 | Packaging (Helm, Kustomize) | A Helm chart for Linkly, values per environment |
| 5 | GitOps with ArgoCD | Git becomes the source of truth: CI bumps the image tag, Argo syncs it |
| 6 | AWS Foundations | IAM, VPC, EC2, S3, ECR, the CLI; deploy Linkly on EC2 by hand, on purpose |
| 7 | Terraform | Module 6 as code: VPC, EKS, RDS, remote state, modules |
| 8 | Production on EKS | Argo deploys Linkly to EKS; autoscaling, AWS secrets, TLS |
| 9 | Ansible | Configure the hosts that aren't on Kubernetes; roles |
| 10 | Python for DevOps | Boto3 scripts: a cost report, snapshot cleanup, a health-check bot |
| 11 | Observability | Prometheus metrics, Grafana dashboards, Loki logs, alerts |
| 12 | DevSecOps & Capstone | Image scanning, signing, policies, secret scanning; then rebuild Linkly end to end with no guide |

Each module also has short **landscape** lessons on the tools it doesn't teach in depth (Jenkins,
GitLab CI, Pulumi, Flux and others): what they are and how they got here.

## How to start

1. Fork this repo and clone your fork.
2. Open [`modules/00-foundations/README.md`](modules/00-foundations/README.md).
3. Every module's README names a **checkpoint branch** (`checkpoint/NN-<module>`): Linkly exactly
   as it should be at the start of that module. Stuck, or jumping in late? Start from there.

On Windows, install WSL2 first: `wsl --install -d Ubuntu-24.04` in an admin PowerShell, then reboot.

## What it costs

Nothing until Module 6. From then on, every AWS lab says what it costs per hour up front and
ends with a **Clean up** step that deletes everything it created.

## The app

[`app/linkly/`](app/linkly/) is a small URL shortener: a web page, a Python API, Postgres, Redis
and a background worker. See its README for how the parts talk to each other.

## Licences

Code (everything in `app/`) is [MIT](LICENSE). Lesson text and diagrams (`modules/`, `docs/`) are
[CC BY 4.0](LICENSE-CONTENT.md).
