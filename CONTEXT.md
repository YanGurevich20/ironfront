# Auth Context (Current State) 20/02/2026

## Stage Semantics
- `stage=dev` always means local development (user-service on localhost, local Postgres, DevAuthProvider).
- `stage=prod` means production (GCP Cloud Run + Cloud SQL, PgsAuthProvider only).

## Environments
- Local dev: `just user-service::dev`; loads `infra/.env.dev` (STAGE=dev, DATABASE_URL → local Postgres).
- Prod API: `https://api.ironfront.live` (Cloud Run + Cloud SQL); `infra/.env.prod` for db-migrate.

## Game Auth Runtime
- `AuthManager` is the auth state orchestrator.
- Provider split:
  - Dev: `DevAuthProvider` (simulated provider proof + delay).
  - Prod/Android: `PgsAuthProvider`.
- `AppConfig` autoload controls runtime config:
  - `stage` (dev = local, prod = GCP)
  - `user_service_base_url` (defaults to localhost:8080 for dev, api.ironfront.live for prod; override with `--user-service-url`)
- API layering:
  - `src/api/api_client.gd` for transport.
  - `src/api/user_service/user_service_client.gd` for user-service endpoints.
- Login UI uses button-based auth state and no offline username flow.

## User Service Runtime
- Hono service with Drizzle + Postgres (Cloud SQL in prod, local Postgres for dev).
- Active auth endpoints:
  - `POST /auth/exchange`
  - `GET /me`
- Session exchange and profile fetch flow is active.

## Infra / Deployment
- Pulumi-managed infra under `infra/`:
  - `project-infra` (stack: prod) for project-wide resources/IAM.
  - `user-service` (stack: prod) for Cloud Run + Cloud SQL + Secret Manager.
- Single deploy target: prod at api.ironfront.live.
- Image deploy flow uses immutable tags and `linux/amd64` buildx images.
- User-service recipes (from `user-service/`): `fix`, `dev`, `push-image`, `db-migrate`, `deploy`.
