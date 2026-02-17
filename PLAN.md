## Resources
- (godot-play-game-services)[https://github.com/godot-sdk-integrations/godot-play-game-services?tab=readme-ov-file]
- (Temporary Agones docs)[https://web.archive.org/web/20241008162226/https://agones.dev/site/docs/overview/]

## Primary tasks
- Bring user data online and integrate with Play Games Services (PGS)
- Add analytics
- Create a regional server cluster with Agones

## Auth + Storage Phase (Clean Cutover)
1. Install and configure PGS plugin in the game client
- Add and configure `godot-play-game-services` for Android builds.
- Implement sign-in flow and request server auth code from client.
- Block progression/online entry until sign-in succeeds.

2. Create `user-service` module on GCP (Cloud Run)
- Add a new top-level `user-service/` module with its own `justfile` and agent docs index.
- Implement `POST /auth/pgs/exchange` to verify/exchange Google auth artifacts and issue app session token.
- Add auth middleware so all player data endpoints trust only app-issued tokens.

3. Provision authoritative player database
- Stand up primary datastore for player profile/progression/economy/loadout state.
- Define canonical account model: `account_id` + mapping to `pgs_player_id`.
- Add schema/version fields and audit fields (`created_at`, `updated_at`).

4. Implement player profile API surface
- Add `GET /me` (fetch profile) and `PUT /me` (update allowed profile fields).
- Keep server authoritative for currencies, progression, unlocks, and loadouts.
- Add request validation, idempotency strategy for write operations, and basic rate limiting.

5. Update game client to use online profile as source of truth
- On successful auth exchange, fetch `/me` and hydrate in-memory player state.
- Replace local-save authoritative writes with API calls for profile mutations.
- Keep local `user://` data only as temporary cache/settings; do not treat it as authority.

6. Add baseline observability and environment setup
- Set up `dev` and `prod` environments, secrets, and deployment pipeline for `user-service`.
- Add structured logging, error reporting, and key auth/profile metrics.
- Configure DB backup/recovery basics before wider playtesting.

7. Explicitly skip data migration for this phase
- No import of existing local `user://` saves.
- Existing local profiles are discarded as part of first online cutover.
