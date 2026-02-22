# Ironfront Monorepo Guide for Agents
## PRODUCTION MODE: RAPID DEVELOPMENT
## PRODUCTION USER COUNT: 0
## TESTERS COUNT: 2

## Terminology
- Use `module` for each top-level component in this repo, and `project` for the entire repo.

## Structure
- Top-level directories are modules (for example `game/`, `matchmaker/`, `user-service/`, `project-infra/`,`fleet/`).
- Each module includes `agent-docs/index.md` as the module docs table of contents.
- Each module has `justfile`, with a `fix` recipe that will run the lint/format/static-analysis tools on the module.

## Tooling
- Root `justfile` orchestrates cross-module workflows.
- Root `justfile` should load modules with `mod <module>` and may expose root aliases.
- Each module has its own `justfile`.

## CORE RULES
### These rules take presedence over all other rules, and represent the core philosophy of the project and developer.
- Use root `just fix` after cross-module changes, otherwise use a targeted `just <module>::fix`.
- Read the module's `agent-docs/index.md` and any files required in that index before beginning implementation.
- No gcloud commands for manipulating infrastructure - everything should be done via the infra repo.
- as long as `PRODUCTION MODE` at the top of this file is set to `RAPID DEVELOPMENT`, use a "fast iteration, zero legacy, not scared of breaking things" mindset. This means:
  - removing lines of code is a success metric, and minimal systems are always more maintainable than complex ones.
  - we can make experimental changes and not be afraid of data loss.
  - we do not need to keep legacy and compatibility wrappers.
  - drizzle push is preferred to migrations.
  - large refactors are welcome and preferred over small targeted changes.
