# Module Rules

## Primary runtime philosophy
- Due to the dynamic nature of the game, where nodes can be added and removed at runtime, with long-chain dependencies from different components (such as a game event updating a UI element far in the tree, while communicating to a network node), it becomes very quickly unfeasible to remember to use methods such as .configure() to pass dependencies, .cleanup() for breakdown, and `if node is null return` checks in critical paths to avoid lifecycle bugs.
- The Primary model we use to make nullability easier is "Scene tree as truth". This means that nodes that should always be present are added as part of the scene and referenced by unique names, and are considered always available to their parents. 
- In regards to configuration, instead of calling activation methods on children, we let them hadnle the internal logic on their _ready() function, and trigger the activation via add_child().

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
