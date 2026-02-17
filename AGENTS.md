# Ironfront Monorepo Guide for Agents

## Terminology
- Use `module` for each top-level component in this repository.
- Use `project` for the entire repository.

## Structure
- Top-level directories are modules (for example `game/`, `matchmaker/`, `user-service/`, `agones/`).
- Each module includes `agent-docs/index.md` as the module docs table of contents.
- Each module has `justfile`, with a `fix` recipe that will run the lint/format/static-analysis tools on the module.

## Tooling
- Root `justfile` orchestrates cross-module workflows.
- Each module has its own `justfile`.
- Root `justfile` should load modules with `mod <module>` and may expose root aliases.

## Global Required Workflow Rules
- Use root `just fix` after cross-module changes, otherwise use a targeted `just <module>::fix`.
- Read the module's `agent-docs/index.md` and any files required in that index before beginning implementation.