# Car Service Tracker

A cross-platform (iOS + Android) app for logging vehicle service history, tracking
costs, and getting smart maintenance reminders. Backend built as Docker-based
microservices, deployed to Kubernetes, with a self-managed GitLab CE CI/CD pipeline.

This repo is the **starting scaffold**: two working backend services (Auth,
Core), shared types, local dev infrastructure, and a mobile app skeleton —
all wired together and verified to build/run. Everything else in the full
proposal (Reminder Service, Notification Service, File Service, PDF export,
Kubernetes manifests, Terraform) builds on top of this foundation.

---

## What's actually running right now

| Component | Status |
|---|---|
| **Auth Service** | ✅ Built, tested, boots and serves `/health`. Register/login/refresh/me routes wired to PostgreSQL. |
| **Core Service** | ✅ Built, tested. Vehicle CRUD + mileage history + service log CRUD, publishes `service_log.created` events to RabbitMQ. |
| **shared-types** | ✅ Builds. Shared TypeScript interfaces used by both services (and importable by the mobile app). |
| **Kubernetes manifests** | ✅ Primary way to run everything now. `k8s/base` (Postgres, RabbitMQ, MinIO, both services, Ingress) + `k8s/overlays/{staging,production}`. Rendered and validated with `kustomize build` — zero errors across all three. See `k8s/README.md`. |
| **docker-compose.yml** | 🟡 Kept only as a fallback/reference for people without a cluster handy — Kubernetes is now the primary path. |
| **Mobile app (React Native)** | ✅ Real native Android + iOS projects (Gradle/Kotlin and Xcode), both fully renamed and verified: installs, type-checks, lints, and passes its render test. Opens directly in Android Studio or Xcode. See `mobile/README.md`, and `mobile/ANDROID_STUDIO_TROUBLESHOOTING.md` if Android Studio shows sync errors on first import. |
| **Reminder Service, Notification Service, File Service** | ⬜ Not yet built — next in line, see `docs/ROADMAP.md`. |
| **Terraform (cluster provisioning), GitLab CE VM setup** | ⬜ Design covered in earlier proposal docs; not yet turned into files in this repo — `k8s/` assumes you already have a cluster (local `kind` or a real one). |

---

## Folder structure

```
car-service-tracker/
├── package.json                # npm workspaces root
├── docker-compose.yml          # fallback/reference - Kubernetes (k8s/) is the primary path now
├── .gitlab-ci.yml              # GitLab CE pipeline (lint, test, SonarQube, build, scan, deploy to k8s)
├── .gitignore
├── scripts/
│   ├── windows/                 # PowerShell (.ps1) scripts - Docker Desktop Kubernetes
│   │   ├── k8s-start-cluster.ps1 / k8s-stop-cluster.ps1
│   │   ├── k8s-build-images.ps1
│   │   ├── k8s-deploy.ps1        # first-time deploy: build + apply + migrate
│   │   ├── k8s-redeploy.ps1      # after code changes: rebuild + rolling restart
│   │   └── k8s-teardown.ps1
│   ├── linux/                   # bash equivalents of the above (also works on macOS)
│   │   └── (same script names, .sh)
│   ├── k8s-deploy-local.sh      # alternative: build + deploy to a `kind` cluster specifically
│   ├── k8s-teardown.sh          # alternative: tear down a `kind` deployment
│   ├── dev-up.sh / dev-down.sh  # docker-compose fallback
│   └── migrate.sh               # docker-compose fallback migrations
├── k8s/
│   ├── kind-cluster.yaml         # local test cluster config (kind alternative)
│   ├── base/                    # namespace, postgres, rabbitmq, minio, both services, ingress
│   └── overlays/{staging,production}/
├── libs/
│   └── shared-types/            # shared TS interfaces (User, Vehicle, ServiceLog, events)
├── services/
│   ├── auth-service/            # signup/login/JWT/refresh tokens
│   └── core-service/            # vehicles + mileage + service logs
├── mobile/                      # React Native app - real native android/ + ios/ projects included
├── infra/
│   ├── postgres-init/           # docker-compose fallback: creates one DB per service
│   └── gateway/                 # docker-compose fallback: NGINX config
└── docs/
    ├── ARCHITECTURE.md
    ├── ROADMAP.md
    └── CI_CD.md
```

---

## Prerequisites

- **Node.js 20+** and **npm 10+** (for local development without Docker)
- **Docker Desktop** with Kubernetes enabled (Settings → Kubernetes → Enable Kubernetes) — works the same way on Windows, macOS, and Linux; this is the recommended way to run the cluster locally (see `k8s/README.md` for the `kind` alternative)
- **kubectl** and **kustomize** (or `kubectl apply -k`, which has it built in)
- **Android Studio** with the Android SDK, and/or **Xcode** (macOS only) — to run the mobile app, see `mobile/README.md`
- A **GitLab CE self-managed instance** (only needed once you push this to a real Git remote and want CI/CD running — see `docs/CI_CD.md`)

---

## Quick start (Kubernetes on Docker Desktop — recommended)

**Windows (PowerShell):**
```powershell
.\scripts\windows\k8s-start-cluster.ps1
.\scripts\windows\k8s-deploy.ps1
kubectl get pods -n car-tracker
```

**Linux / macOS (bash):**
```bash
chmod +x scripts/linux/*.sh
./scripts/linux/k8s-start-cluster.sh
./scripts/linux/k8s-deploy.sh
kubectl get pods -n car-tracker
```

Full instructions (Ingress setup for a single gateway URL, the `kind`
alternative, and deploying to a real staging/production cluster) are in
**`k8s/README.md`**.

### Try the API end-to-end

```bash
# Port-forward (works the same on Windows/Linux/macOS):
kubectl port-forward -n car-tracker svc/auth-service 4001:4001
kubectl port-forward -n car-tracker svc/core-service 4002:4002

curl -X POST http://localhost:4001/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"me@example.com","password":"supersecret123","displayName":"Ali"}'

curl -X POST http://localhost:4002/vehicles \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <accessToken>" \
  -d '{"make":"Honda","model":"Civic","year":2019,"currentMileage":42000,"mileageUnit":"km"}'
```

### After changing service code

```powershell
.\scripts\windows\k8s-redeploy.ps1     # rebuild images + rolling restart
```
```bash
./scripts/linux/k8s-redeploy.sh
```

### Tearing down

```powershell
.\scripts\windows\k8s-teardown.ps1            # keeps data volumes
.\scripts\windows\k8s-teardown.ps1 -Wipe      # also wipes Postgres/MinIO data
.\scripts\windows\k8s-stop-cluster.ps1        # stops Docker Desktop entirely
```
```bash
./scripts/linux/k8s-teardown.sh          # keeps data volumes
./scripts/linux/k8s-teardown.sh -v       # also wipes Postgres/MinIO data
./scripts/linux/k8s-stop-cluster.sh      # stops Docker Desktop entirely
```

---

## Quick start (docker-compose — fallback, if you don't have a cluster handy)

```bash
./scripts/dev-up.sh
./scripts/migrate.sh
curl http://localhost:8080/health/auth
curl http://localhost:8080/health/core
./scripts/dev-down.sh
```

---

## Running the mobile app (Android Studio)

```bash
cd mobile
npm install
```

Then open the **`mobile/android`** folder in Android Studio, run `npm start`
in a terminal to start Metro, and hit Run in Android Studio (or `npm run
android`). Full walkthrough — including the `10.0.2.2` networking gotcha for
reaching your backend from the emulator — is in **`mobile/README.md`**.

---

## Quick start (without Docker — running services directly with Node)

Useful for faster iteration while actively coding a service.

```bash
# Install all workspace dependencies once, from the repo root:
npm install
npm run build   # builds shared-types + both services

# Start Postgres/RabbitMQ some other way (e.g. just the infra via Docker):
docker compose up -d postgres rabbitmq minio

# In one terminal:
cp services/auth-service/.env.example services/auth-service/.env
npm run dev:auth

# In another terminal:
cp services/core-service/.env.example services/core-service/.env
npm run dev:core
```

Each service auto-reloads on file changes (via `tsx watch`).

---

## Running tests

```bash
# All services:
npm run test

# Just one service:
npm run test --workspace=auth-service
npm run test --workspace=core-service
```

Current coverage is intentionally focused on pure logic (token helpers,
mileage conversion) that doesn't need a live database — route-level
integration tests against a real Postgres instance are a good next addition
(e.g. via `testcontainers` or a docker-compose-based test DB).

---

## Linting

```bash
npm run lint   # runs eslint across every service workspace
```

---

## Database migrations

Each service owns its own database(s) and ships plain `.sql` migration files
under `src/db/migrations/`, run in filename order by a small custom runner
(`src/db/migrate.ts`) — no external migration framework dependency for now.
As the schema grows, consider swapping this for `node-pg-migrate` or Prisma
Migrate.

To add a migration: drop a new `NNN_description.sql` file into the relevant
`migrations/` folder (or `migrations/vehicle/` / `migrations/servicelog/` for
Core Service) and re-run `./scripts/migrate.sh`.

---

## Environment variables

Each service has a `.env.example` documenting what it needs. Copy to `.env`
for local (non-Docker) runs — docker-compose already injects the equivalent
values directly as container environment variables, so you don't need `.env`
files when running via `dev-up.sh`.

| Service | Key vars |
|---|---|
| `auth-service` | `DATABASE_URL`, `JWT_ACCESS_SECRET`, `JWT_REFRESH_SECRET` |
| `core-service` | `VEHICLE_DATABASE_URL`, `SERVICELOG_DATABASE_URL`, `JWT_ACCESS_SECRET` (must match auth-service's), `RABBITMQ_URL` |

**`JWT_ACCESS_SECRET` must be identical across `auth-service` and
`core-service`** — Core Service doesn't issue tokens, it only verifies ones
signed by Auth Service.

**Dependency sources (npm/Gradle/Docker) are separate from the above** —
this project is wired to pull all of those through a self-hosted Nexus
Repository instead of public registries. See **`docs/NEXUS.md`** for the
full setup and exactly which files (`.npmrc`, `mobile/android/build.gradle`,
both Dockerfiles, `.gitlab-ci.yml`) need your real Nexus hostname/credentials.

---

## API surface (current)

### Auth Service (`:4001`, or `/auth/*` via gateway `:8080`)
| Method | Path | Description |
|---|---|---|
| POST | `/auth/register` | Create an account, returns user + tokens |
| POST | `/auth/login` | Log in, returns user + tokens |
| POST | `/auth/refresh` | Exchange a refresh token for a new access token |
| GET | `/auth/me` | Get the current user (requires `Authorization: Bearer <accessToken>`) |
| GET | `/health` | Health check |

### Core Service (`:4002`, or `/vehicles`, `/service-logs` via gateway `:8080`)
| Method | Path | Description |
|---|---|---|
| GET | `/vehicles` | List the authenticated user's vehicles |
| POST | `/vehicles` | Create a vehicle |
| GET | `/vehicles/:id` | Get one vehicle |
| POST | `/vehicles/:id/mileage` | Log a new mileage reading |
| GET | `/service-logs?vehicleId=...` | List service logs for a vehicle |
| GET | `/service-logs/types` | List predefined service type presets |
| POST | `/service-logs` | Create a service log entry (publishes `service_log.created` event) |
| GET | `/health` | Health check |

All routes except `/health` and `/service-logs/types` require
`Authorization: Bearer <accessToken>`.

---

## Further documentation

- **`docs/ARCHITECTURE.md`** — service boundaries, data ownership, event flow
- **`docs/ROADMAP.md`** — what's built vs. what's next (Reminder Service, Notification Service, File Service, Kubernetes manifests, Terraform)
- **`docs/CI_CD.md`** — how `.gitlab-ci.yml` maps to a self-managed GitLab CE + Kubernetes setup
- **`docs/NEXUS.md`** — routing npm, Gradle/Android, and Docker base-image dependencies through a self-hosted Nexus Repository instead of public registries
- **`mobile/README.md`** — mobile app: Android Studio + Xcode setup steps, project structure
- **`mobile/ANDROID_STUDIO_TROUBLESHOOTING.md`** — fixes for the common Gradle-sync-cascade errors on first import
