# Landscape: CI beyond GitHub Actions

> **You need:** Lessons 1–6 · **Time:** ~40 min · **Start from:** `checkpoint/02-ci`

## Why this matters

Your next job may use Jenkins, GitLab CI or something else entirely. The good news: the ideas
you just learned (triggers, jobs, stages, runners, caches, artifacts, secrets, least privilege)
are the same everywhere. Only the file format changes.

## Concept

- **Jenkins** began as Hudson (2004) and was renamed Jenkins in 2011. It's self-hosted, endlessly
  extensible through plugins, and pipelines are written in Groovy in a `Jenkinsfile`. Many
  enterprises still run it: it lives inside their network, works with anything, and they
  have years of jobs built on it. The cost is operating it yourself: upgrades, plugins, security.
- **GitLab CI** is built into GitLab: a `.gitlab-ci.yml` with stages and jobs, runners you can
  host yourself or use GitLab's. A natural choice when the code already lives in GitLab.
- **CircleCI, Azure Pipelines, Bitbucket Pipelines:** hosted services with the same shape.
- **Tekton and Argo Workflows** run pipelines as Kubernetes resources, which is popular with
  platform teams once everything runs on Kubernetes (Module 3 onwards).
- **Hosted vs self-hosted runners:** hosted runners (like ours) are zero maintenance and start
  clean every time. Self-hosted runners can reach private networks and special hardware, but you
  patch and secure them.

## Example

Linkly's lint → test → smoke stages, sketched for the other two big tools (not run in this course):

**GitLab CI** (`.gitlab-ci.yml`):

```yaml
stages: [lint, test, smoke]

lint:
  stage: lint
  image: python:3.12-slim
  script:
    - pip install ruff==0.17.0
    - ruff check app/linkly

test:
  stage: test
  image: docker:27
  services: [docker:27-dind]
  parallel:
    matrix:
      - SERVICE: [api, worker]
  script:
    - docker build --target test -t linkly-$SERVICE:test app/linkly/$SERVICE
    - docker run --rm linkly-$SERVICE:test

smoke:
  stage: smoke
  image: docker:27
  services: [docker:27-dind]
  variables:
    DOCKER_TLS_CERTDIR: "/certs"     # the docker image then finds the dind daemon by itself
  script:
    - apk add --no-cache bash curl
    - LINKLY_HOST=docker app/linkly/smoke-test.sh   # with dind, published ports live on the "docker" host
```

**Jenkins** (`Jenkinsfile`):

```groovy
pipeline {
  agent any
  stages {
    stage('Lint')  { steps { sh 'ruff check app/linkly' } }
    stage('Test') {
      parallel {
        stage('api')    { steps { sh 'docker build --target test -t linkly-api:test app/linkly/api && docker run --rm linkly-api:test' } }
        stage('worker') { steps { sh 'docker build --target test -t linkly-worker:test app/linkly/worker && docker run --rm linkly-worker:test' } }
      }
    }
    stage('Smoke') { steps { sh 'app/linkly/smoke-test.sh' } }
  }
}
```

Put them next to our `ci.yml`: stages and jobs map almost one to one.

## Lab

- [ ] Map each of our jobs to a GitLab CI stage
- [ ] Sketch the Jenkinsfile stage for the test matrix
- [ ] Name one reason a company would keep Jenkins

## Check yourself

1. Hosted or self-hosted runners: when would you choose self-hosted?

<details><summary>Answer</summary>

When jobs must reach things inside a private network (an internal database or registry), need
special hardware (GPUs, ARM machines), or when rules say code can't run on a vendor's machines.

</details>

2. What carries over when you move from GitHub Actions to another CI tool?

<details><summary>Answer</summary>

Almost everything conceptual: triggers, stages and jobs, parallelism, caching, artifacts,
secrets, least-privilege tokens, and gating publishing on tests. The scripts the jobs run
move over almost unchanged: the Docker builds as they are, the smoke test with one setting
(`LINKLY_HOST=docker` when Docker runs as a separate "dind" service).

</details>
