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
- `user-service-infra:allowUnauthenticated`
- `user-service-infra:enableCustomDomain`
- `user-service-infra:customDomain`
- `user-service-infra:minInstanceCount`
- `user-service-infra:maxInstanceCount`

## Custom Domain
When `enableCustomDomain=true`, this stack provisions an HTTPS global load balancer with a managed certificate and exports the IPv4 address to use for an `A` record on the configured domain.
