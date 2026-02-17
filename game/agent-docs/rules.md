# Module Rules

## LLM Refactor Rules
- Prioritize reducing architectural complexity and clarifying ownership over minimizing diff size.
- Do not add new util/helper files unless explicitly requested.
- Prefer deleting/merging redundant files and call paths when refactoring.
- Breaking internal APIs is allowed during refactors, but all call sites must be migrated in the same change.
- Choose the largest safe refactor that can be validated in one pass, not the smallest local patch.
- A refactor is incomplete if ownership is still split across layers after behavior is fixed.

## Scene Lifecycle Architecture Guideline
- Use scene composition to encode invariants, and node lifetime to encode state.
- Scene-wired dependencies should be treated as always present; avoid runtime null checks for invariant structure.
- Represent ephemeral gameplay/session state as dynamic child nodes that are added/removed on lifecycle transitions.
- Prefer mount/unmount of subtree roots to model start/stop over distributed `is_active` flags.
- Keep lifecycle boundaries explicit: orchestrator nodes own creation/teardown and expose stable signals to parents.

## Folder Structure Guideline
- Prefer organizing folders to mirror ownership and lifecycle boundaries in the scene tree.
- Keep stable orchestrators at the domain root (for example `arena/arena_client.*`).
- Place dynamically instantiated session/match subtrees under a nested folder (for example `arena/runtime/*`).
- Perfect 1:1 tree mirroring is not required, but parent orchestrator + dynamic subtree grouping should stay consistent.
