# Roadmap

## Done in this scaffold

- [x] Monorepo with npm workspaces (`libs/*`, `services/*`)
- [x] `@car-tracker/shared-types` - shared TS interfaces
- [x] Auth Service - register/login/refresh/me, bcrypt + JWT, Postgres migrations, Dockerfile
- [x] Core Service - vehicle CRUD, mileage history, service log CRUD, service type presets, RabbitMQ event publishing, Postgres migrations (2 DBs), Dockerfile
- [x] docker-compose for local dev (Postgres multi-DB, RabbitMQ, MinIO, both services, NGINX gateway)
- [x] Unit tests for both services (token helpers, mileage conversion) - all passing
- [x] `.gitlab-ci.yml` pipeline (lint → test → SonarQube → build → Trivy scan → deploy)
- [x] Mobile app skeleton - navigation, login screen, vehicle list screen, API client

## Next up (in suggested order)

### 1. Reminder Service
- New service + `reminder` database (already created by `infra/postgres-init`)
- Consume `service_log.created` from RabbitMQ, recalculate `next_due_date`/`next_due_mileage`
- Daily cron job (`node-cron`) checking for due reminders → publish `reminder.due`
- CRUD endpoints so the mobile app can create/edit custom reminder rules

### 2. Notification Service
- New service + `notification` database
- Device token registration endpoint (mobile app calls this after requesting push permission)
- Consume `reminder.due` → send via FCM (Android) / APNs (iOS)
- Firebase Admin SDK setup (needs a Firebase project + service account key)

### 3. File Service
- Wire up MinIO (local) / S3 (production) for receipt photo and PDF uploads
- Signed upload URL endpoint so the mobile app can upload directly to storage without proxying bytes through the service
- Link uploaded `file_key`s to `service_log_attachments` (Core Service already has this table)

### 4. PDF/Export Service
- Stateless service reading from Core Service's API
- Generate a shareable PDF service history report (useful for reselling a car)

### 5. Mobile app - remaining screens
- `AddVehicleScreen`, `VehicleDetailScreen` (service history timeline), `AddServiceLogScreen`
- Push notification permission + device token registration flow
- Generate actual native `ios/`/`android/` project folders (see `mobile/README.md`)

### 6. Infrastructure - turn the earlier design into real files
- Terraform modules for EKS/GKE cluster + node groups (design already covered in earlier proposal doc; not yet materialized as `.tf` files in this repo)
- GitLab CE VM Terraform + Omnibus install script
- Kubernetes manifests (Deployment/Service/Ingress/HPA per service) + Helm chart or Kustomize overlays for staging vs. production
- GitLab Agent for Kubernetes setup for GitOps-style deploys

### 7. Hardening
- Route-level integration tests against a real Postgres instance (e.g. via `testcontainers`)
- Rate limiting on Auth Service (`express-rate-limit`) - not yet added
- Refresh token rotation/revocation-on-reuse detection
- Structured logging (pino) + request correlation IDs across services
- Sentry wiring for both services (currently just `console.error`)

## Explicitly deferred (Phase 2, per the original proposal)

- OCR receipt scanning
- OBD-II Bluetooth integration for automatic mileage sync
- Family/shared account access
- Predictive maintenance suggestions
