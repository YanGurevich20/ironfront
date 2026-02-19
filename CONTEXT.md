# Auth Context (Current State) 20/02/2026

## Environments
- Local dev: user-service runs on localhost (STAGE=dev, local Postgres or cloud-sql-proxy)
- Prod API: `https://api.ironfront.live` (Cloud Run + Cloud SQL)

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
- User-service recipes:
  - `just user-service::db-migrate`
  - `just user-service::deploy`
  - `just user-service::smoke`
  - `just user-service::release`
