# project-infra

Pulumi stack for shared infrastructure in a single GCP project.

## Bootstrap
1. `source .config`
2. `pulumi login gs://$PULUMI_STATE_BUCKET`
3. `pnpm install`
4. `pulumi stack init dev` (first time)
5. `pulumi config set gcp:project <your-project-id>`
6. `pnpm run pulumi:preview`
7. `pnpm run pulumi:up`

## Managed resources (initial)
- VPC + subnet
- Artifact Registry Docker repository
