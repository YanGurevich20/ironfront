## Module Rules
- Keep shared foundation infrastructure in `project-infra/`.
- Keep service deployment resources in their service directory under this module.
- Prefer non-destructive migrations and explicit review for IAM/networking changes.
- Keep non-sensitive config in plain centralized config code, and keep prod secrets in CI/CD-reachable secret stores.

## Config and secret policy
- Keep non-sensitive runtime config centralized in plain config code.
- Use `.env` for local/dev secrets.
- Use CI/CD-reachable secret stores (for example Secret Manager) for prod secrets.

## Env Files
- `infra/.env.dev`: local development (STAGE=dev, DATABASE_URL, etc.). Used by `just user-service::dev`. Gitignored.
- `infra/.env.prod`: production deployment (USER_SERVICE_DB_PASSWORD, PGS_WEB_CLIENT_SECRET, etc.). Used by `just user-service::db-migrate` via resolve_stack_env. Gitignored.
