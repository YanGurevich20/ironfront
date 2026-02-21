# Code Patterns (LLM-Directed)

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
- For external time fields (for example HTTP/API payloads), convert at the boundary to Unix timestamp integers (seconds) and use Unix `int` internally.

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

## 5) Nullable Built-in Types
- GDScript has no `int?` or `T | null` syntax for built-ins.
- Use `Variant` where a value may be null (for example API fields that omit or explicitly null a field).
- Coerce to a concrete type at use sites: `int(v) if v != null else 0`.

Good:
```gdscript
var username_updated_at_unix: Variant = body.get("username_updated_at_unix", null)
if username_updated_at_unix == null or int(username_updated_at_unix) <= 0:
	show_username_prompt()
```

Bad:
```gdscript
var username_updated_at: int = body.get("username_updated_at_unix", 0)
```

## 9) Return Structured Results for Cross-Layer Operations
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

## 12) Prefer `class_name` Globals for Static APIs
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

## 13) Cached Resource Binding Pattern (DataStore-Backed)
- For resources loaded through `DataStore.load_or_create(...)`, treat them as cache-backed singleton state objects in runtime usage.
- Preferred binding is top-level typed vars at class scope, then use those vars directly in methods.
- Do not repeatedly call `get_instance()` in the same node/script when a single bound reference is sufficient.
- These resources are considered always available in runtime and are only persisted to disk when `save()` is called explicitly.

Good:
```gdscript
class_name TankDisplayPanel extends Control

var account: Account = Account.get_instance()
var preferences: Preferences = Preferences.get_instance()

func _ready() -> void:
	Utils.connect_checked(
		account.username_updated,
		func(new_username: String) -> void: username_label.text = new_username
	)
	Utils.connect_checked(
		preferences.selected_tank_id_updated, func(_tank_id: String) -> void: display_tank()
	)
	display_tank()

func display_tank() -> void:
	var tank_spec: TankSpec = TankManager.tank_specs.get(preferences.selected_tank_id)
	if tank_spec == null:
		return
	tank_display.texture = tank_spec.preview_texture
```

Bad:
```gdscript
class_name TankDisplayPanel extends Control

func _ready() -> void:
	var account: Account = Account.get_instance()
	var preferences: Preferences = Preferences.get_instance()
	Utils.connect_checked(
		account.username_updated,
		func(new_username: String) -> void: username_label.text = new_username
	)
	display_tank()
	Utils.connect_checked(
		preferences.selected_tank_id_updated, func(_tank_id: String) -> void: display_tank()
	)

func display_tank() -> void:
	var preferences: Preferences = Preferences.get_instance()
	var tank_spec: TankSpec = TankManager.tank_specs.get(preferences.selected_tank_id)
	if tank_spec == null:
		return
	tank_display.texture = tank_spec.preview_texture
```

## Documentation Requirement
- When a new pattern is adopted in this repo, update this file with a concrete good/bad example.
