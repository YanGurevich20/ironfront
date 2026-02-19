# Module Rules

- Server is authoritative for profile/progression/economy/loadout state.
- Stage policy is enforced server-side (`dev` may accept `dev` provider; `prod` rejects it).
- Keep endpoint request/response contracts explicit and typed.
- Keep non-sensitive config centralized in plain config code; use `.env` for dev secrets and secret managers for prod.
