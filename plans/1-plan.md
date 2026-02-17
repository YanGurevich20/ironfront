# Online-First Auth + Storage Plan (Phase 1)

## Scope
- Implement auth and authoritative online player data as the first online-first milestone.
- No migration from existing local saves (`user://`) is required.
- Keep local/editor development compatibility with a dedicated dev auth path.

## Decisions Locked
- Client will support two auth providers:
	- `PGS` provider (Android runtime).
	- `DEV` provider (editor/desktop/local development).
- Server will accept stage configuration (for example `--stage=dev`).
	- `dev`: allows `DEV` provider.
	- `prod`: rejects `DEV` provider and allows only `PGS`.
- Login menu will authenticate only; no username entry there.
- Username registration/update happens in-game after auth.
	- Default username is seeded from PGS display name (or provider display name fallback).
- Auth attempt behavior: auto-attempt on app start, with manual retry.

## Architecture Overview
- Client:
	- `AuthProvider` interface + provider implementations (`PgsAuthProvider`, `DevAuthProvider`).
	- `AuthOrchestrator` state machine handles startup auth and session lifecycle.
- Server (`user-service`):
	- `POST /auth/exchange` verifies provider proof and issues app session token.
	- `GET /me` loads authoritative profile.
	- `PATCH /me/username` completes registration/update flow.
- Storage:
	- Authoritative DB stores player progression, economy, unlocked content, loadouts, selected tank, profile.
	- Local files are cache/settings only, never source of truth.

## Intended End-to-End Flow (Chart)
```text
+--------------------+          +--------------------------+          +----------------------+
| Game Client        |          | Auth Provider            |          | user-service         |
| (AuthOrchestrator) |          | (PGS or DEV)             |          | (Cloud Run)          |
+---------+----------+          +-------------+------------+          +----------+-----------+
          |                                   |                                  |
          | app start                         |                                  |
          |---------------------------------->| sign_in()                        |
          |                                   |                                  |
          |<----------------------------------| AuthIdentity + provider proof    |
          |                                   |                                  |
          | POST /auth/exchange {provider, proof, metadata}                      |
          |--------------------------------------------------------------------->|
          |                                                                      | verify proof
          |                                                                      | map/create account
          |                                                                      | issue session token
          |<---------------------------------------------------------------------|
          | {session_token, account_id, is_new_account, profile}                 |
          |                                                                      |
          | GET /me (Bearer session_token)                                       |
          |--------------------------------------------------------------------->|
          |<---------------------------------------------------------------------|
          | authoritative profile                                                 |
          |                                                                      |
          | if profile.username missing -> PATCH /me/username                    |
          |--------------------------------------------------------------------->|
          |<---------------------------------------------------------------------|
          | username updated                                                      |
```

## Auth Contract (Pseudocode)
```ts
// Shared provider identity payload returned to AuthOrchestrator
type AuthIdentity = {
	provider: "pgs" | "dev";
	provider_user_id: string;     // PGS player id or deterministic dev id
	display_name: string;         // PGS display name or dev display name
	proof: string;                // PGS server auth code or dev signed token
	expires_at_unix?: number;     // optional if provider returns expiry
};

interface AuthProvider {
	is_available(): boolean;
	sign_in(): Promise<AuthIdentity>;   // includes provider proof payload
	sign_out(): Promise<void>;
}
```

```ts
// Backend API contracts
POST /auth/exchange
req = {
	provider: "pgs" | "dev",
	proof: string,
	client: {
		stage: "dev" | "prod",
		app_version: string,
		platform: string
	}
}
res = {
	account_id: string,
	session_token: string,
	expires_at_unix: number,
	is_new_account: boolean,
	profile: {
		username: string,
		display_name: string
	}
}

GET /me
res = {
	account_id: string,
	username: string,
	display_name: string,
	progression: object,
	economy: object,
	loadout: object
}

PATCH /me/username
req = { username: string }
res = { username: string }
```

## Stage Policy (Server)
```pseudo
if stage == "prod":
	accept provider == "pgs" only
	reject provider == "dev"

if stage == "dev":
	accept "pgs" and "dev"
	require dev secret/signed token rules for "dev"
```

## Client Runtime Flow (Pseudocode)
```pseudo
on_app_start:
	provider = resolve_provider_for_platform_and_stage()
	if not provider.is_available():
		show_auth_error("AUTH PROVIDER UNAVAILABLE")
		show_retry_button()
		return

	result = await provider.sign_in()
	exchange = await POST /auth/exchange(result)
	store_session(exchange.session_token, exchange.expires_at_unix)

	profile = await GET /me()
	if profile.username is empty:
		open_registration_overlay(default_name = result.display_name)
	else:
		enter_garage(profile)

on_registration_submit(username):
	await PATCH /me/username(username)
	profile = await GET /me()
	enter_garage(profile)
```

## First Implementation Slice
1. Add `AuthProvider` interface and `DevAuthProvider` in game client.
2. Add `AuthOrchestrator` and wire startup auto-auth + retry UI states.
3. Add server `--stage` handling and `POST /auth/exchange` with `dev` provider acceptance in `dev` only.
4. Add `GET /me` and `PATCH /me/username` with minimal profile schema.
5. Switch garage bootstrap to load profile from API, not local `PlayerData` authority.

## Non-Goals in This Phase
- PGS snapshots integration.
- Existing local save import/migration.
- Full analytics and Agones deployment work (tracked separately).
