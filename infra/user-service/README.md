# user-service infra

Pulumi stack for deploying `user-service` on Cloud Run.

## Commands
- `pnpm run pulumi:preview`
- `pnpm run pulumi:up`

## Config
- `gcp:project`
- `gcp:region`
- `user-service-infra:artifactRepoId`
- `user-service-infra:imageTag`
- `user-service-infra:serviceName`
- `user-service-infra:stage`
- `user-service-infra:sessionTtlSeconds`
- `user-service-infra:allowUnauthenticated`
- `user-service-infra:enableCustomDomain`
- `user-service-infra:customDomain`
- `user-service-infra:minInstanceCount`
- `user-service-infra:maxInstanceCount`
- `user-service-infra:dbInstanceName`
- `user-service-infra:dbName`
- `user-service-infra:dbUserName`
- `user-service-infra:dbUserPassword` (set via `pulumi config set --secret`)
- `user-service-infra:dbTier`
- `user-service-infra:dbEdition`
- `user-service-infra:dbDeletionProtection`
- `user-service-infra:dbSecretName`
- `user-service-infra:dbVersion`

## Database + Secret Flow
- Provisions Cloud SQL Postgres instance/database/user.
- Builds a `DATABASE_URL` secret in Secret Manager using Cloud SQL Unix socket format.
- Grants Cloud Run runtime service account:
  - `roles/cloudsql.client`
  - `roles/secretmanager.secretAccessor`
- Injects `DATABASE_URL` + `SESSION_TTL_SECONDS` into Cloud Run.
- Mounts Cloud SQL socket on `/cloudsql`.

## Custom Domain
When `enableCustomDomain=true`, this stack provisions an HTTPS global load balancer with a managed certificate and exports the IPv4 address to use for an `A` record on the configured domain.
