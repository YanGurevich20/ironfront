# Module Rules

- Server is authoritative for profile/progression/economy/loadout state.
- stage=dev means local development; stage=prod means production. Policy enforced server-side (dev accepts DevAuthProvider; prod rejects it).
- Keep endpoint request/response contracts explicit and typed.
- Keep non-sensitive config centralized in plain config code; use `infra/.env.dev` for local dev and secret managers for prod.
