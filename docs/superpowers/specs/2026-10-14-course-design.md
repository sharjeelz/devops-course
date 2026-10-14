# DevOps course: layered, one app end to end

A free, open-source, self-paced DevOps/Cloud course, published as a public GitHub repo of Markdown
lessons. The author learns each module first, then turns their notes and mistakes into the lesson.
Inspired by TechWorld with Nana's DevOps Bootcamp, rebuilt on a modern stack and the author's own
structure.

## Who it is for

Learners with some tech background (developers, IT support, sysadmins). Module 0 is a refresher
with self-tests, not a from-zero Linux course. English.

## Principles

- **One app, all the way.** Every module adds one layer to the same app, **Linkly**. Lab N's
  result is lab N+1's starting point.
- **Checkpoint branches.** `checkpoint/NN-<module>` holds Linkly as it should be at the *start* of
  module NN, so a stuck learner can jump in anywhere.
- **Side labs only when needed.** A concept that is clearer outside Linkly (shell scripting, a
  first Python script) gets a small side lab, and the module then brings it back to Linkly.
- **Local first.** Labs run free on a laptop (Docker, kind). Real AWS only from Module 6, and
  every AWS lab opens with a cost warning (rough $ per hour) and ends with a "destroy everything"
  step.
- **Modern core, landscape for the rest.** Each module teaches one main tool in depth, plus a
  short landscape lesson: what the alternatives are, where they came from and how they have
  evolved (e.g. Jenkins → GitHub Actions).

## Linkly (the running app)

A URL shortener, small enough to understand in 5 minutes:

- `web`: a small static frontend
- `api`: Python FastAPI (create a short link, redirect, stats)
- `postgres`: links and click counts
- `redis`: redirect cache plus a queue
- `worker`: consumes click events and updates the counts

It lives in `app/linkly/`, with tests so that CI has something real to run from Module 2 on.

## Module map

| # | Module | Layer added to Linkly | Landscape |
|---|---|---|---|
| 0 | Foundations Check | Linux, shell, networking, Git refreshers plus a self-test; run Linkly by hand on bare Linux and feel the pain | — |
| 1 | Containers (Docker) | Dockerfile per service, multi-stage builds, Compose for the whole stack, volumes | Podman, containerd |
| 2 | CI with GitHub Actions | Lint, test, build images, push to GHCR, versioning | Jenkins, GitLab CI |
| 3 | Kubernetes Core (kind) | Deployments, Services, ConfigMaps/Secrets, StatefulSet for Postgres, Ingress/Gateway API | Swarm, Nomad |
| 4 | Packaging (Helm, Kustomize) | Helm chart for Linkly, values per environment | — |
| 5 | GitOps with ArgoCD | Git is the source of truth; CI bumps the image tag, Argo syncs it; full CI/CD locally | Flux, push-based CD |
| 6 | AWS Foundations | IAM, VPC, EC2, S3, ECR, CLI; deploy Linkly on EC2 by hand, on purpose | Azure/GCP equivalents |
| 7 | Terraform | Module 6 as code: VPC, EKS, RDS, remote state, modules | Pulumi, OpenTofu, CloudFormation |
| 8 | Production on EKS | Argo deploys Linkly to EKS; autoscaling, AWS secrets, TLS | ECS/Fargate |
| 9 | Ansible | Configure the non-Kubernetes hosts (e.g. a bastion); roles | Chef/Puppet, cloud-init |
| 10 | Python for DevOps | Boto3 scripts: cost report, snapshot cleanup, a Linkly health-check bot | Bash vs Python vs Go |
| 11 | Observability | Prometheus metrics in the API, Grafana dashboards, Loki logs, alerts | Datadog, OpenTelemetry |
| 12 | DevSecOps & Capstone | Trivy scanning, cosign signing, Kyverno policies, secret scanning; capstone: rebuild Linkly end to end with no guide | Service mesh, platform engineering (Backstage), AI in DevOps |

## Repo layout

```
devops-course/
  README.md                 course intro, module map, how to start
  modules/
    00-foundations/
      README.md             module overview (first "# " heading is the title)
      01-linux-refresher.md lessons, ordered by numeric prefix
      ...
    01-containers/
    ...
  app/linkly/               the running app (main = final state)
  docs/superpowers/         specs and plans
```

Folder and file names define the order: `NN-slug`. There is no manifest to keep in sync.

## Lesson template

Every lesson file follows the same shape:

1. **Why this matters**: the problem, ideally one the learner just hit in the previous lesson
2. **Concept**: the idea itself, independent of any tool, with a diagram where it helps
3. **Example**: a worked walkthrough on Linkly with the exact commands and expected output
4. **Lab**: a `- [ ]` checklist of steps the learner does on their own copy
5. **Check yourself**: 3–5 questions, with answers in a collapsed `<details>` block
6. **Stretch** (optional): a harder variation
7. **Clean up**: required for any lab that creates cloud resources

Each module's `README.md` states what the learner needs from earlier modules, what they will
build, roughly how long it takes, and which checkpoint branch to start from.

## Authoring loop (per module)

Learn it (author works through it, keeping notes in the Jarvis Course tab) → draft the lessons
from those notes → run the labs from the checkpoint branch on a clean machine → publish.

## Out of scope for now

Videos, a course website (MkDocs/Docusaurus can sit on top of this same Markdown later), quizzes
with scoring, translations, paid tiers.
