# GDScript Guidelines (LLM-Directed)

This file is written for code-generating agents. Follow it literally.

## 1) Naming and File Basics
- Use tabs for indentation.
- Use `snake_case` for variables/functions.
- Use `PascalCase` for `class_name`.
- Use `snake_case` for scene/resource filenames.

## 2) Node Access and Scene Tree Wiring
- Prefer `%UniqueName` for sibling/child dependencies.
- Avoid deep path lookups in runtime logic.
- Long-lived systems should be scene children, not ad-hoc `new()+add_child()` in many places.

Good:
```gdscript
@onready var network_server: NetworkServer = %Network
@onready var arena_runtime: ArenaRuntime = %ArenaRuntime
```

Bad:
```gdscript
var network_server: Node = get_node("/root/Main/Runtime/Network")
```

## 3) Type Everything You Can
- Prefer typed fields, typed arrays, and typed dictionaries.
- Avoid `Object` unless absolutely necessary.

## 4) Parse at Boundaries, Keep Internals Typed
- RPC payloads and generic dictionaries are trust boundaries.
- Parse/coerce once, then continue with typed values.

Good:
```gdscript
var peer_id: int = int(payload.get("peer_id", 0))
var player_name: String = str(payload.get("player_name", ""))
if peer_id <= 0 or player_name.is_empty():
	return
```

Bad:
```gdscript
if payload["peer_id"] > 0:
	do_spawn(payload["peer_id"], payload["player_name"])
```

## 5) Signals for Cross-System Communication
- Use signals for intent/event boundaries.
- Avoid direct two-way coupling across domains.
- Pattern:
  - net layer emits intent signal
  - orchestrator handles it
  - runtime mutates world

## 6) One Owner Per Responsibility
- Do not split one decision across multiple layers.
- Example ownership split:
  - network layer: transport + protocol validation
  - runtime layer: spawn selection + world mutation
  - orchestrator: wiring + lifecycle

Good:
```gdscript
var spawn_result: Dictionary = arena_runtime.spawn_peer_tank_at_random(
	peer_id, player_name, tank_id
)
```

Bad:
```gdscript
# network picks spawn and runtime also validates/changes it later
```

## 7) Keep Hot Paths Simple
- Validate invariants once at startup.
- Avoid repeated null checks in per-tick/per-message loops unless state is truly optional.

Good:
```gdscript
func _physics_process(delta: float) -> void:
	var states: Array[Dictionary] = arena_runtime.step_authoritative_runtime(arena_session_state, delta)
	network_server.set_authoritative_player_states(states)
```

Bad:
```gdscript
if arena_runtime != null and arena_session_state != null and network_server != null:
	# repeated every tick
```

## 8) Return Structured Results for Cross-Layer Operations
- For helper calls crossing boundaries, return result dictionaries with explicit status.

Good:
```gdscript
return {
	"success": false,
	"reason": "NO_SPAWN_AVAILABLE",
}
```

Then handle explicitly:
```gdscript
if not result.get("success", false):
	var reason: String = str(result.get("reason", "FAILED"))
	return
```

## 9) Prefer Small Helpers Over Monoliths
- If a method grows too large, extract cohesive helpers.
- Helpers should have clear input/output and no hidden side effects when possible.

## 10) Avoid These Patterns
- `.call(...)` to bypass typing.
- Leading-underscore parameter names used only to dodge warnings.
- Deep `get_node("A/B/C/D")` when `%UniqueName` is possible.
- Unbounded file growth; extract helpers before scripts become hard to scan.

## 11) Prefer `class_name` Globals for Static APIs
- For utility classes with `class_name`, call static functions directly by class name.
- Do not add local `preload(...)` aliases for globally-registered utility classes unless there is a demonstrated load-order problem.

Good:
```gdscript
var player_data: PlayerData = DataStore.load_or_create(PlayerData, PlayerData.FILE_NAME)
DataStore.save(player_data, PlayerData.FILE_NAME)
```

Bad:
```gdscript
const DATA_STORE := preload("res://src/game_data/data_store.gd")
var player_data: PlayerData = DATA_STORE.load_or_create(PlayerData, PlayerData.FILE_NAME)
DATA_STORE.save(player_data, PlayerData.FILE_NAME)
```

## Documentation Requirement
- When a new pattern is adopted in this repo, update this file with a concrete good/bad example.
