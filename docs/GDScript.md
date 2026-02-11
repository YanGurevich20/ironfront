# GDScript Best Practices

This document captures practical GDScript patterns adopted in this repository as we improve performance, clarity, and maintainability.

## Type System and Data Shapes
- Prefer typed dictionaries for stable maps.
- Example:
```gdscript
var player_tanks_by_peer_id: Dictionary[int, Tank] = {}
var arena_spawn_transforms_by_id: Dictionary[StringName, Transform2D] = {}
```
- Use typed arrays when shape is known (`Array[int]`, `Array[Dictionary]`).
- Keep cache dictionaries typed (for example, `Dictionary[String, ShellSpec]`) to avoid repeated casts at read sites.

## Casting and Parsing
- Avoid redundant `int()`, `float()`, `bool()`, and `str()` casts when values are already constrained by typed storage.
- Parse and coerce data at trust boundaries (RPC payloads, untyped dictionary payloads), then keep internal state typed.
- Prefer:
```gdscript
var join_success: bool = join_result.get("success", false)
```
- Avoid:
```gdscript
var join_success: bool = bool(join_result.get("success", false))
```
unless input is truly ambiguous and requires explicit coercion.

## Dictionary Iteration
- Iterate directly with typed loop variables when container shape is known.
- Prefer:
```gdscript
for spawn_id: StringName in arena_spawn_transforms_by_id.keys():
	...
```
- Avoid generic `Variant` iteration unless absolutely necessary.

## Control Flow Safety
- Keep `continue` / `return` statements minimal and verify follow-up blocks are not accidentally nested under them.
- After refactors, quickly re-check indentation-sensitive blocks (especially when appending snapshot/state payloads).

## Networking and Session State
- Keep transport-level validation in `net/*` and authoritative gameplay mutation in `core/*` runtime scripts.
- Store validated session/runtime values in typed structures; downstream code should consume typed state, not re-validate repeatedly.
- Validate required gameplay prerequisites (for example, non-empty spawn pools) before starting network listeners, and fail fast on invalid startup state.
- Split visual feedback from authoritative simulation (for example, a `play_fire_effect()` path separate from shell spawning) so remote clients can replay effects without duplicating gameplay state.

## Refactoring Discipline
- Apply low-risk type/cast cleanup incrementally in touched areas rather than broad churn across unrelated systems.
- Extract self-contained logic into focused helpers when a script grows large or mixes responsibilities.
- Good extraction targets are pure data transforms (for example, snapshot builders) that take typed inputs and return typed outputs.
- When scripts approach lint file-size limits, extract cohesive utility modules (for example, CLI parsing or match-result builders) instead of compressing readability with dense in-file edits.
- Keep online and offline UX lifecycle paths separate when product behavior diverges (for example, match-end flow vs offline mission result flow).
- Keep shared UI base classes presentational (layout/panel helpers) and wire navigation/back-routing explicitly in each concrete overlay.
- After each optimization pass, run `just fix`.
