# Module Structure

- `project-infra/`: shared project-scale resources (VPC, shared registries, common IAM baselines).
- `user-service/`: user-service deployment resources.
- Add module-specific infrastructure under sibling directories (`matchmaker/`, `fleet/`) as those services are introduced.
