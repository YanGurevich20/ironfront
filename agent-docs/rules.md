# Repository Rules

## Required Workflow
- Mandatory read: `agent-docs/gdscript.md` before making or reviewing GDScript changes.
- Always run `just fix` after making code changes.

## LLM Refactor Rules
- Prioritize reducing architectural complexity and clarifying ownership over minimizing diff size.
- Do not add new util/helper files unless explicitly requested.
- Prefer deleting/merging redundant files and call paths when refactoring.
- Breaking internal APIs is allowed during refactors, but all call sites must be migrated in the same change.
- Choose the largest safe refactor that can be validated in one pass, not the smallest local patch.
- A refactor is incomplete if ownership is still split across layers after behavior is fixed.
