# project-infra

Pulumi stack for shared infrastructure in a single GCP project.

## Bootstrap
1. `source .config`
2. `pulumi login gs://$PULUMI_STATE_BUCKET`
3. `pnpm install`
4. `pulumi stack init prod` (first time)
5. `pulumi config set gcp:project <your-project-id>`
6. `pnpm run pulumi:preview`
7. `pnpm run pulumi:up`

## Managed resources (initial)
- VPC + subnet
- Artifact Registry Docker repository
- Artifact Registry pull IAM bindings for Cloud Run and runtime service accounts
- CI service account
- Artifact Registry writer IAM binding for CI service account
- Cloud Build source bucket IAM binding for CI service account
- Cloud Build log-writer IAM binding for CI service account

## Required stack config
- `project-infra:artifactRepoId`
- `project-infra:vpcName`
- `project-infra:subnetName`
- `project-infra:subnetCidr`
- `project-infra:artifactRepoPullProjectNumber`
- `project-infra:ciServiceAccountId`
- `project-infra:artifactRepoRuntimeServiceAccounts` (list of service account emails)
- `project-infra:cloudBuildSourceBucket`
