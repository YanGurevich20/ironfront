# Module Rules

- Keep shared foundation infrastructure in `project-infra/`.
- Keep service deployment resources in their service directory under this module.
- Prefer non-destructive migrations and explicit review for IAM/networking changes.
- Keep non-sensitive config in plain centralized config code, and keep prod secrets in CI/CD-reachable secret stores.
