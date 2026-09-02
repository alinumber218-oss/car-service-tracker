# CI/CD Setup Guide

This project's `.gitlab-ci.yml` is written for a **self-managed GitLab CE**
instance with a **Kubernetes-executor runner**. This doc covers the one-time
setup needed to make that pipeline actually run.

## 1. Push this repo to your GitLab CE instance

```bash
git init
git remote add origin https://gitlab.yourcompany.example.com/your-group/car-service-tracker.git
git add .
git commit -m "Initial scaffold: auth-service, core-service, shared-types, mobile skeleton"
git push -u origin main
```

## 2. Enable the Container Registry

GitLab CE includes a container registry out of the box, but it must be
enabled at the instance level (`/etc/gitlab/gitlab.rb`:
`registry_external_url` configured) by whoever administers the GitLab VM.
Once enabled, `$CI_REGISTRY_IMAGE` is automatically available in pipeline
jobs — no extra config needed in this repo.

## 3. Register a Kubernetes-executor GitLab Runner

Rather than a static runner VM, register a runner that itself runs as pods
inside your Kubernetes cluster, so it scales with pipeline load:

```bash
helm repo add gitlab https://charts.gitlab.io
helm install gitlab-runner gitlab/gitlab-runner \
  --namespace gitlab-runner --create-namespace \
  --set gitlabUrl=https://gitlab.yourcompany.example.com \
  --set runnerRegistrationToken=<token-from-gitlab-admin-area> \
  --set runners.executor=kubernetes
```

## 4. Set required CI/CD variables

In GitLab: **Settings → CI/CD → Variables**, add:

| Variable | Purpose |
|---|---|
| `SONAR_HOST_URL` | URL of your self-hosted SonarQube instance |
| `SONAR_TOKEN` | SonarQube auth token (mark as **masked**) |
| `STAGING_KUBE_CONTEXT` | kubectl context name for the staging cluster |
| `PRODUCTION_KUBE_CONTEXT` | kubectl context name for the production cluster |

`CI_REGISTRY`, `CI_REGISTRY_USER`, `CI_REGISTRY_PASSWORD` are provided
automatically by GitLab CE for the built-in registry — no need to set these
yourself.

## 5. SonarQube (self-hosted)

Run SonarQube via Docker on its own host (or a small dedicated namespace in
the cluster):

```bash
docker run -d --name sonarqube -p 9000:9000 sonarqube:community
```

Then create a project matching `$CI_PROJECT_NAME` and generate a token for
`$SONAR_TOKEN`. The pipeline's `sonarqube-scan` job will fail the build if
the quality gate isn't met (`-Dsonar.qualitygate.wait=true`).

## 6. kubectl access from CI jobs

The `deploy-staging` / `deploy-production` jobs assume `kubectl` inside the
job image already has contexts named `$STAGING_KUBE_CONTEXT` /
`$PRODUCTION_KUBE_CONTEXT` available. In practice, this means either:
- Baking a kubeconfig into a CI/CD variable (file type) and referencing it, or
- Switching to the **GitLab Agent for Kubernetes** for a pull-based GitOps
  flow instead of pushing `kubectl set image` commands from CI (recommended
  once you're past the initial scaffold stage — see the earlier Kubernetes +
  GitLab addendum for the reasoning).

## 7. What the pipeline does, stage by stage

1. **install** — `npm install` per changed service, cached as an artifact for later stages
2. **lint** — ESLint per changed service
3. **test** — Jest with coverage per changed service, reported to GitLab's coverage UI
4. **sonarqube** — full-repo static analysis + quality gate (blocks merge if it fails)
5. **build** — Docker multi-stage build per changed service, pushed to the GitLab registry tagged with the commit SHA
6. **scan** — Trivy scans the just-built image for CRITICAL/HIGH CVEs, fails the pipeline if any are found
7. **deploy-staging** — automatic on `main`, updates the staging Deployment's image
8. **deploy-production** — manual approval gate (`when: manual`), same image promoted to production

## 8. Secret scanning

`gitleaks` runs as its own job (not gated on GitLab Ultimate's integrated
Secret Detection feature) and fails the pipeline if anything resembling a
credential is committed. Add a `.gitleaks.toml` at the repo root later if you
need to tune false positives.
