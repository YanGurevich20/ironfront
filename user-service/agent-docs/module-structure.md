# Module Structure

- `src/server.ts`: HTTP server bootstrap.
- `src/routes/`: HTTP route handlers.
- `src/auth/`: session/auth primitives.
- Persistence is Postgres-first via Drizzle and Cloud SQL.

## Justfile (from user-service/)
- `fix`: lint/typecheck
- `dev`: run user-service locally; loads `infra/.env.dev` (STAGE=dev, DATABASE_URL, etc.)
- `push-image`: build and push Docker image to Artifact Registry
- `db-migrate`: run migrations against prod Cloud SQL (requires cloud-sql-proxy, `infra/.env.prod`)
- `deploy`: push-image, set imageTag in Pulumi prod stack, pulumi up
