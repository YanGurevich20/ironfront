# Auth + Backend Plan

## Current Status

### Client auth/UI refactor completed
- Replaced old login username flow with auth-button-driven flow.
- Removed startup auto-sign-in; auth is now user-initiated.
- Wired logout to `AuthManager.sign_out()`.
- Added realistic delay support in `DevAuthProvider` for testing.
- Renamed `AuthOrchestrator` to `AuthManager`.

### Backend module scaffolding completed
- Added top-level modules:
	- `user-service/`
	- `matchmaker/`
	- `fleet/`
	- `infra/` (renamed from `project-infra`)
- Added module docs + `justfile` scaffolds for new modules.
- Updated root `justfile` to load all modules.

### `user-service` API scaffold completed
- TypeScript + `pnpm` setup in `user-service/`.
- Implemented minimal endpoints:
	- `GET /healthz`
	- `POST /auth/exchange`
	- `GET /me` (Bearer token protected)
- Current persistence/session is in-memory (intentional first pass).

### Infra reset + restructure completed
- Destroyed and removed old Pulumi stacks for clean restart.
- Consolidated infra code under `infra/` with shared toolchain.
- Split infra domains:
	- `infra/project-infra/` (shared foundation)
	- `infra/user-service/` (service deployment)
- Moved Pulumi backend config into `Pulumi.yaml` files (GCS backend).
- Enforced config-first style (no fallback defaults for deployment config).

### Foundation infra + user-service deployment infra in code
- `infra/project-infra/` defines:
	- Artifact Registry repo
	- VPC + subnet
	- required APIs
- `infra/user-service/` defines:
	- Cloud Run service
	- runtime service account
	- required APIs
	- custom domain HTTPS LB path:
		- serverless NEG
		- backend service
		- URL map
		- managed SSL cert
		- target HTTPS proxy
		- global forwarding rule + static IPv4

## Immediate Next Steps

1. Apply infra stacks (fresh)
- `infra/project-infra`: create shared infra.
- `infra/user-service`: create Cloud Run + HTTPS LB resources.
- Ensure `PULUMI_CONFIG_PASSPHRASE` is loaded from local `infra/.env`.

2. DNS for custom domain
- Set `A` record for `api.ironfront.live` to Pulumi output `customDomainDnsARecord`.
- Wait for managed cert to move to active.

3. Build and deploy `user-service`
- Build/push image to Artifact Registry.
- Deploy Cloud Run revision (via `user-service/cloudbuild.yaml`).
- Confirm service is reachable by both Cloud Run URL and custom domain.

4. First backend test pass
- `GET /healthz` returns expected stage.
- `POST /auth/exchange` works for `provider=dev` in `dev`.
- `GET /me` rejects missing token, accepts valid token.
- Verify stable account mapping behavior for repeated dev identity.

5. Integrate game client with backend auth exchange
- After provider sign-in:
	- call `/auth/exchange`
	- store session token
	- call `/me`
	- use returned profile for garage bootstrap path
- Keep local `PlayerData` temporarily for non-migrated fields until profile API expands.

6. Expand profile API for planned flow
- Add `PATCH /me/username`.
- Add schema validation constraints for username.
- Add lightweight structured logging around auth/profile paths.

## Near-Term Follow-ups
- Replace in-memory store with Cloud SQL-backed persistence adapter.
- Add DB migrations and seed/version strategy.
- Add minimal auth/profile integration tests in CI.
- Add infra domains under `infra/` for `matchmaker` and `fleet` as they begin implementation.
