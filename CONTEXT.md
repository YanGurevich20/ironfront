# Auth Context (Current State) 19/02/2026

## Environments
- Dev API domain: `https://api-dev.ironfront.live`
- Prod API domain target: `https://api.ironfront.live`

## Game Auth Runtime
- `AuthManager` is the auth state orchestrator.
- Provider split:
  - Dev: `DevAuthProvider` (simulated provider proof + delay).
  - Prod/Android: `PgsAuthProvider`.
- `AppConfig` autoload controls runtime config:
  - `stage`
  - `user_service_base_url` (with optional `--user-service-url` override)
- API layering:
  - `src/api/api_client.gd` for transport.
  - `src/api/user_service/user_service_client.gd` for user-service endpoints.
- Login UI uses button-based auth state and no offline username flow.

## User Service Runtime
- Hono service with Drizzle + Postgres (Cloud SQL).
- Active auth endpoints:
  - `POST /auth/exchange`
  - `GET /me`
- Session exchange and profile fetch flow is active.

## Infra / Deployment
- Pulumi-managed infra under `infra/`:
  - `project-infra` for project-wide resources/IAM.
  - `user-service` for service/db/runtime resources.
- Dev user-service deploy target: Cloud Run + Cloud SQL + Secret Manager.
- Image deploy flow uses immutable tags and `linux/amd64` buildx images.
- User-service recipes available:
  - `just user-service::dev-db-migrate`
  - `just user-service::dev-deploy`
  - `just user-service::dev-smoke`
  - `just user-service::dev-release`

## Verified
- Dev deploy succeeds.
- Dev smoke succeeds against `api-dev` (`/auth/exchange` then `/me`).
- Local game auth works against dev API.

## Next
1. Deploy/test prod API with real PGS provider from device.
2. Wire authoritative user/progression/economy/loadout data flows to DB-backed APIs.
