# Running on Kubernetes

Everything (Postgres, RabbitMQ, MinIO, Auth Service, Core Service, Ingress)
runs as Kubernetes workloads instead of `docker-compose`. The
`docker-compose.yml` at the repo root is kept only as a quick reference /
fallback for people who don't have a cluster handy — the manifests here are
the primary way to run the stack.

Manifests were rendered and validated with `kustomize build` during
development (zero errors across base, staging, and production overlays) —
see `docs/CI_CD.md` for how this fits the GitLab CI pipeline.

**Recommended local setup: Docker Desktop's built-in Kubernetes.** It works
identically on Windows, macOS, and Linux, and — unlike `kind` or
Minikube — shares the same image store as `docker build`, so there's no
separate "load the image into the cluster" step. `kind` is documented further
down as an alternative if you'd rather not use Docker Desktop's Kubernetes.

## Folder layout

```
k8s/
├── kind-cluster.yaml           # alternative: local test cluster config (kind)
├── base/
│   ├── namespace.yaml
│   ├── postgres/postgres.yaml       # StatefulSet + PVC + init ConfigMap (creates 5 DBs)
│   ├── rabbitmq/rabbitmq.yaml       # Deployment + Service
│   ├── minio/minio.yaml             # Deployment + Service + PVC
│   ├── auth-service/
│   │   ├── auth-service.yaml         # Deployment + Service + HPA + Secret + ConfigMap
│   │   └── migrate-job.yaml          # One-shot Job to run DB migrations
│   ├── core-service/
│   │   ├── core-service.yaml
│   │   └── migrate-job.yaml
│   ├── gateway/ingress.yaml          # NGINX Ingress routing /auth, /vehicles, /service-logs
│   └── kustomization.yaml            # Ties the above together
└── overlays/
    ├── staging/kustomization.yaml     # Points at staging image tags + hostname
    └── production/kustomization.yaml  # 3 replicas, production image tags + hostname
```

Scripts live under `scripts/windows/` and `scripts/linux/` — one pair per
platform for every operation (start/stop the cluster, build images, deploy,
redeploy, teardown), since starting/stopping Docker Desktop itself works
differently on each OS.

## Prerequisites

- **Docker Desktop** (Windows, macOS, or Linux) with **Kubernetes enabled**:
  Docker Desktop → Settings → Kubernetes → check "Enable Kubernetes" → Apply & Restart.
  This is a one-time manual step — it can't be toggled purely from the CLI.
- `kubectl` (bundled with Docker Desktop, or install separately)
- `kustomize` — or use `kubectl apply -k`, which has it built in

## Option A: Docker Desktop Kubernetes (recommended)

### Windows (PowerShell)

```powershell
# 1. Start Docker Desktop and wait for its Kubernetes cluster to be ready
.\scripts\windows\k8s-start-cluster.ps1

# 2. Build images, deploy everything, run migrations
.\scripts\windows\k8s-deploy.ps1

# 3. Check status
kubectl get pods -n car-tracker
```

After changing service code:
```powershell
.\scripts\windows\k8s-redeploy.ps1     # rebuilds images + rolling-restarts both Deployments
```

Tear down / stop:
```powershell
.\scripts\windows\k8s-teardown.ps1            # removes the deployment, keeps data volumes
.\scripts\windows\k8s-teardown.ps1 -Wipe      # also wipes Postgres/MinIO data
.\scripts\windows\k8s-stop-cluster.ps1        # stops Docker Desktop entirely
```

### Linux / macOS (bash)

```bash
chmod +x scripts/linux/*.sh

# 1. Start Docker Desktop and wait for its Kubernetes cluster to be ready
./scripts/linux/k8s-start-cluster.sh

# 2. Build images, deploy everything, run migrations
./scripts/linux/k8s-deploy.sh

# 3. Check status
kubectl get pods -n car-tracker
```

After changing service code:
```bash
./scripts/linux/k8s-redeploy.sh        # rebuilds images + rolling-restarts both Deployments
```

Tear down / stop:
```bash
./scripts/linux/k8s-teardown.sh        # removes the deployment, keeps data volumes
./scripts/linux/k8s-teardown.sh -v     # also wipes Postgres/MinIO data
./scripts/linux/k8s-stop-cluster.sh    # stops Docker Desktop entirely
```

### Reaching the API

Once deployed, port-forward directly (simplest option, works immediately with no Ingress setup):

```bash
kubectl port-forward -n car-tracker svc/auth-service 4001:4001
kubectl port-forward -n car-tracker svc/core-service 4002:4002
curl http://localhost:4001/health
curl http://localhost:4002/health
```

Or set up the Ingress for a single gateway URL — install the NGINX Ingress
Controller's generic **cloud** provider manifest (Docker Desktop's
Kubernetes automatically binds `LoadBalancer`-type Services to `localhost`,
so this "just works" without any cloud provider):

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml
kubectl wait --namespace ingress-nginx --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller --timeout=120s
```

Then add `127.0.0.1 car-tracker.local` to your hosts file
(`C:\Windows\System32\drivers\etc\hosts` on Windows, `/etc/hosts` on
Linux/macOS — requires admin/sudo) and hit
`http://car-tracker.local/auth/register` etc.

## Option B: `kind` (Kubernetes-in-Docker), if you'd rather not use Docker Desktop's Kubernetes

```bash
# 1. Install kind: https://kind.sigs.k8s.io/docs/user/quick-start/#installation
kind create cluster --config k8s/kind-cluster.yaml

# 2. Install the NGINX Ingress Controller (kind-specific manifest - different from the "cloud" one above)
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
kubectl wait --namespace ingress-nginx --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller --timeout=120s

# 3. Build + load images into kind, deploy, migrate
chmod +x scripts/*.sh
./scripts/k8s-deploy-local.sh
```

`kind` requires an extra "load the image into the cluster" step
(`kind load docker-image ...`, already handled inside
`scripts/k8s-deploy-local.sh`) because — unlike Docker Desktop's own
Kubernetes — a `kind` cluster runs in its own Docker container with a
separate internal image store.

## Option C: Deploy to a real cluster (staging/production)

This assumes CI has already built and pushed images to your GitLab
Container Registry (see `.gitlab-ci.yml` / `docs/CI_CD.md`) — the overlays
reference `registry.gitlab.yourcompany.example.com/...`, replace with your
actual registry path.

```bash
kubectl apply -k k8s/overlays/staging      # or overlays/production
kubectl apply -f k8s/base/auth-service/migrate-job.yaml -n car-tracker-staging
kubectl apply -f k8s/base/core-service/migrate-job.yaml -n car-tracker-staging
```

In practice, this is what `.gitlab-ci.yml`'s `deploy-staging`/
`deploy-production` jobs already do — see `docs/CI_CD.md` for wiring it into
the pipeline instead of running manually.

## Secrets — read this before going to production

Every `Secret` in `k8s/base/**/*.yaml` currently has **placeholder values**
(`dev-only-access-secret-change-me`, `app_password`, etc.) so the stack is
runnable out of the box for local testing. **Do not deploy these placeholder
values to a real staging/production cluster.** Before deploying anywhere
that matters:

1. Generate real random secrets (`openssl rand -hex 32` for JWT secrets)
2. Either `kubectl create secret` directly (out-of-band, not committed to Git),
   or adopt **Sealed Secrets** / the **External Secrets Operator** pulling
   from AWS Secrets Manager or Vault
3. Remove the plaintext `stringData` blocks from the YAML once you've moved
   to one of the above

## Persistent storage note

Postgres uses a `PersistentVolumeClaim` via `volumeClaimTemplates` (5Gi) and
MinIO uses a standalone 5Gi PVC. Docker Desktop's Kubernetes provides a
default `hostpath` StorageClass that satisfies these automatically — data
persists across pod restarts but lives inside the Docker Desktop VM, so it's
tied to that Docker Desktop installation (not portable to a different
machine). On a real cloud cluster, make sure a proper StorageClass (e.g.
`gp3` on EKS) is set as default, or specify `storageClassName` explicitly.

## What's intentionally not here yet

- Reminder Service / Notification Service / File Service manifests — add a
  new folder under `k8s/base/` for each once those services exist (see
  `docs/ROADMAP.md`), following the same Secret/ConfigMap/Deployment/Service
  pattern as `auth-service/`.
- TLS on the Ingress (cert-manager + Let's Encrypt) — straightforward to add
  once you have a real domain instead of `.local`/`.example.com` placeholders.
- A service mesh — still not needed at this stage.
