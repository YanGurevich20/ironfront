# GDScript Guidelines

## Style and Naming
- Use tabs for indentation (Godot default).
- Use `snake_case` for functions and variables.
- Use `PascalCase` for `class_name` declarations.
- Use `snake_case` for scene/resource names (`.tscn`, `.tres`).

## Dependency and Runtime Wiring
- Prefer direct `class_name` references over local `preload(...)` aliases when the class is globally registered.
- Prefer concrete typed fields over `Object` to keep method calls discoverable and compiler-checked.
- Construct runtime helpers with typed `ClassName.new()` and attach them directly, rather than casting through `Node`.
- Keep names aligned with the class (`ClientPlayerProfileUtils`, not `ClientPlayerProfileUtilsData`) unless the value is truly data-only.

## Repository Code Rules
- Avoid leading-underscore parameter names (for example `_visible`) as a shadowing workaround; use specific, descriptive names.
- When referencing nodes in scripts, set a Unique Name and use `%NodeName` access.
- Never use `.call(...)` as a type-resolution workaround. If types look stale, check open Godot editor tabs/files and refresh there first.

## Typing and Data Shapes
- Prefer typed dictionaries for stable maps.
- Prefer typed arrays when shape is known.
- Keep cache dictionaries typed to minimize downstream casts.

```gdscript
var player_tanks_by_peer_id: Dictionary[int, Tank] = {}
var arena_spawn_transforms_by_id: Dictionary[StringName, Transform2D] = {}
```

## Casting and Parsing
- Avoid redundant casts when values are already constrained by typed storage.
- Parse/coerce at trust boundaries (RPC payloads, untyped dictionaries), then keep runtime state typed.

Prefer:
```gdscript
var join_success: bool = join_result.get("success", false)
```

Use explicit coercion only for genuinely ambiguous input.

## Iteration and Control Flow
- Iterate with typed loop variables where possible.
- Keep `continue`/`return` usage tight and verify indentation-sensitive blocks after edits.

## Networking and Runtime Separation
- Keep transport/protocol validation in `src/net/*`.
- Keep authoritative gameplay/runtime mutation in `src/core/*`.
- Split visual replay effects from authoritative gameplay simulation where appropriate.

## Refactoring Practices
- Apply low-risk cleanups incrementally in touched areas.
- Extract cohesive helpers/modules when scripts grow too large.
- Prefer extracting pure data transforms over dense in-place edits.
- Keep online and offline lifecycle flows separate when behavior diverges.

## Documentation Requirement
- When a new, more efficient GDScript pattern is discovered in this repo, document it in `docs/GDScript.md`.
