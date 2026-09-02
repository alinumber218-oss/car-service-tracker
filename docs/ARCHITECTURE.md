# Architecture

## Service boundaries (current + planned)

| Service | Status | Owns | Talks to |
|---|---|---|---|
| **Auth Service** | ✅ Built | `users`, `refresh_tokens` (DB: `auth`) | Nothing — self-contained |
| **Core Service** | ✅ Built | `vehicles`, `mileage_history` (DB: `vehicle`); `service_types`, `service_logs`, `service_log_attachments` (DB: `servicelog`) | Publishes `service_log.created` to RabbitMQ; verifies JWTs issued by Auth Service |
| **Reminder Service** | ⬜ Planned | Reminder rules, due dates (DB: `reminder`) | Consumes `service_log.created`; calls Core Service to read current vehicle mileage; publishes `reminder.due` |
| **Notification Service** | ⬜ Planned | Device tokens, notification log (DB: `notification`) | Consumes `reminder.due`; calls FCM/APNs |
| **File Service** | ⬜ Planned | File metadata only — actual bytes in S3/MinIO | Called directly by the mobile app for uploads; referenced by Core Service via `file_key` |
| **PDF/Export Service** | ⬜ Planned | Stateless | Reads from Core Service's API to build exportable service history PDFs |

Note: the original proposal's 8-service breakdown is intentionally collapsed
here into "Auth" + "Core" (Vehicle + Service-Log combined) to keep the
starting scaffold manageable. Splitting Vehicle and Service-Log into fully
separate services later is straightforward since they already use separate
databases (`vehicle` vs `servicelog`) — it's mostly a matter of moving
`src/routes/vehicles.ts` into its own Express app.

## Why no cross-service foreign keys

Each service's database only knows about its own tables. `service_logs.vehicle_id`
is a plain UUID column with **no** `REFERENCES vehicles(id)` constraint,
because `vehicles` lives in a different physical database (`vehicle` vs
`servicelog`) owned by a different part of the codebase. Referential
integrity across that boundary is enforced in application code instead (see
the "owned" ownership check in `services/core-service/src/routes/serviceLogs.ts`,
which confirms the vehicle belongs to the requesting user before allowing a
service log against it).

## Event flow (today)

```
Mobile App
   │  POST /service-logs
   ▼
Core Service (Service-Log routes)
   │  1. Validates the vehicle belongs to the user
   │  2. Inserts into service_logs
   │  3. Publishes `service_log.created` to the "service-log-events" fanout exchange
   ▼
RabbitMQ
   │  (no consumer yet - Reminder Service will subscribe here once built)
   ▼
[Reminder Service - not yet built]
```

The publisher (`src/events/publisher.ts`) is intentionally best-effort: if
RabbitMQ is unreachable, the service log is still saved and the user's
request succeeds — a missed reminder recalculation is far less costly than
losing someone's service record.

## Authentication flow

1. Mobile app calls `POST /auth/register` or `/auth/login` → Auth Service
   returns `{ accessToken, refreshToken }`.
2. Mobile app stores both tokens (refresh token in secure storage) and sends
   `Authorization: Bearer <accessToken>` on every subsequent request to
   *any* service, not just Auth Service.
3. Core Service verifies that access token itself (`middleware/verifyToken.ts`)
   using a `JWT_ACCESS_SECRET` shared with Auth Service — it does not call
   Auth Service over the network to validate tokens. This keeps
   verification fast and avoids Auth Service becoming a bottleneck/single
   point of failure for every request across every service.
4. When the access token expires (15 min default), the app calls
   `POST /auth/refresh` with the refresh token to get a new access token.

## Local dev topology

```
                     ┌─────────────────────┐
                     │   API Gateway :8080  │ (NGINX, infra/gateway/nginx.conf)
                     └──────────┬───────────┘
                 ┌──────────────┼──────────────┐
                 ▼                             ▼
       ┌──────────────────┐          ┌───────────────────┐
       │ auth-service:4001 │          │ core-service:4002  │
       └─────────┬─────────┘          └─────────┬──────────┘
                 │                              │
                 ▼                              ▼
       ┌────────────────────────────────────────────────┐
       │              postgres:5432                       │
       │   databases: auth, vehicle, servicelog,          │
       │              reminder (unused yet),               │
       │              notification (unused yet)            │
       └────────────────────────────────────────────────┘
                                                  │
                                                  ▼
                                       ┌────────────────────┐
                                       │  rabbitmq:5672/15672 │
                                       └────────────────────┘

       ┌────────────────────┐
       │  minio:9000/9001    │  (S3-compatible; not yet used by any service)
       └────────────────────┘
```
