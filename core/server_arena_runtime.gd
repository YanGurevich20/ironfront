class_name ServerArenaRuntime
extends Node

var arena_level: ArenaLevelMvp
var arena_spawn_transforms_by_id: Dictionary = {}
var player_tanks_by_peer_id: Dictionary = {}
var spawn_ids_by_peer_id: Dictionary = {}
var last_consumed_input_tick_by_peer_id: Dictionary = {}


func initialize_runtime(arena_level_packed_scene: PackedScene) -> bool:
	_clear_runtime()
	if arena_level_packed_scene == null:
		push_error("[server][arena-runtime] missing arena level scene")
		return false

	var arena_level_node: Node = arena_level_packed_scene.instantiate()
	var arena_level_candidate: ArenaLevelMvp = arena_level_node as ArenaLevelMvp
	if arena_level_candidate == null:
		push_error("[server][arena-runtime] arena level scene root must use ArenaLevelMvp script")
		arena_level_node.queue_free()
		return false

	add_child(arena_level_candidate)
	arena_level = arena_level_candidate

	var validation_result: Dictionary = arena_level.validate_spawn_markers()
	var is_valid: bool = bool(validation_result.get("valid", false))
	var spawn_count: int = int(validation_result.get("spawn_count", 0))
	var empty_spawn_id_count: int = int(validation_result.get("empty_spawn_id_count", 0))
	var duplicate_spawn_ids: Array = validation_result.get("duplicate_spawn_ids", [])
	if not is_valid:
		push_error(
			(
				"[server][arena-runtime] invalid spawn config count=%d empty_ids=%d duplicates=%s"
				% [spawn_count, empty_spawn_id_count, duplicate_spawn_ids]
			)
		)
		_clear_runtime()
		return false

	arena_spawn_transforms_by_id = arena_level.get_spawn_transforms_by_id().duplicate(true)
	print(
		(
			"[server][arena-runtime] initialized level=res://levels/arena/arena_level_mvp.tscn count=%d"
			% spawn_count
		)
	)
	return true


func get_spawn_transforms_by_id() -> Dictionary:
	return arena_spawn_transforms_by_id.duplicate(true)


func spawn_peer_tank(
	peer_id: int, player_name: String, spawn_id: StringName, spawn_transform: Transform2D
) -> void:
	if arena_level == null:
		push_warning("[server][arena-runtime] spawn ignored: arena level missing")
		return
	if player_tanks_by_peer_id.has(peer_id):
		despawn_peer_tank(peer_id, "REPLACED_EXISTING_TANK")

	var spawned_tank: Tank = TankManager.create_tank(
		TankManager.TankId.M4A1_SHERMAN, TankManager.TankControllerType.DUMMY
	)
	spawned_tank.global_transform = spawn_transform
	arena_level.add_child(spawned_tank)
	player_tanks_by_peer_id[peer_id] = spawned_tank
	spawn_ids_by_peer_id[peer_id] = spawn_id
	last_consumed_input_tick_by_peer_id[peer_id] = 0

	print(
		(
			(
				"[server][arena-runtime] tank_spawned peer=%d player=%s "
				+ "spawn_id=%s tank_instance=%s"
			)
			% [peer_id, player_name, spawn_id, str(spawned_tank.get_instance_id())]
		)
	)


func despawn_peer_tank(peer_id: int, reason: String) -> void:
	var spawned_tank: Tank = player_tanks_by_peer_id.get(peer_id)
	if spawned_tank != null:
		spawned_tank.queue_free()
	player_tanks_by_peer_id.erase(peer_id)
	spawn_ids_by_peer_id.erase(peer_id)
	last_consumed_input_tick_by_peer_id.erase(peer_id)
	print("[server][arena-runtime] tank_despawned peer=%d reason=%s" % [peer_id, reason])


func step_authoritative_runtime(arena_session_state: ArenaSessionState) -> Array[Dictionary]:
	var snapshot_player_states: Array[Dictionary] = []
	if arena_session_state == null:
		return snapshot_player_states
	var peer_ids: Array[int] = arena_session_state.get_peer_ids()
	for peer_id: int in peer_ids:
		var spawned_tank: Tank = player_tanks_by_peer_id.get(peer_id)
		if spawned_tank == null:
			continue
		var peer_state: Dictionary = arena_session_state.get_peer_state(peer_id)
		if peer_state.is_empty():
			spawned_tank.reset_input()
			continue

		_apply_peer_input_intent_to_tank(peer_id, spawned_tank, peer_state)
		var tank_position: Vector2 = spawned_tank.global_position
		var tank_rotation: float = spawned_tank.global_rotation
		var tank_linear_velocity: Vector2 = spawned_tank.linear_velocity
		arena_session_state.set_peer_authoritative_state(
			peer_id, tank_position, tank_rotation, tank_linear_velocity
		)
		(
			snapshot_player_states
			. append(
				{
					"peer_id": peer_id,
					"player_name": str(peer_state.get("player_name", "")),
					"position": tank_position,
					"rotation": tank_rotation,
					"linear_velocity": tank_linear_velocity,
					"last_processed_input_tick": int(peer_state.get("last_input_tick", 0)),
				}
			)
		)
	return snapshot_player_states


func _apply_peer_input_intent_to_tank(
	peer_id: int, spawned_tank: Tank, peer_state: Dictionary
) -> void:
	var left_track_input: float = clamp(float(peer_state.get("input_left_track", 0.0)), -1.0, 1.0)
	var right_track_input: float = clamp(float(peer_state.get("input_right_track", 0.0)), -1.0, 1.0)
	var turret_aim: float = clamp(float(peer_state.get("input_turret_aim", 0.0)), -1.0, 1.0)
	var fire_pressed: bool = bool(peer_state.get("input_fire_pressed", false))
	var input_tick: int = int(peer_state.get("last_input_tick", 0))
	var last_consumed_input_tick: int = int(last_consumed_input_tick_by_peer_id.get(peer_id, 0))

	spawned_tank.left_track_input = left_track_input
	spawned_tank.right_track_input = right_track_input
	spawned_tank.turret_rotation_input = turret_aim

	if input_tick > last_consumed_input_tick:
		last_consumed_input_tick_by_peer_id[peer_id] = input_tick
		if fire_pressed:
			spawned_tank.fire_shell()


func _exit_tree() -> void:
	_clear_runtime()


func _clear_runtime() -> void:
	for peer_id_variant: Variant in player_tanks_by_peer_id.keys():
		var peer_id: int = int(peer_id_variant)
		var spawned_tank: Tank = player_tanks_by_peer_id.get(peer_id)
		if spawned_tank == null:
			continue
		spawned_tank.queue_free()
	player_tanks_by_peer_id.clear()
	spawn_ids_by_peer_id.clear()
	last_consumed_input_tick_by_peer_id.clear()
	arena_spawn_transforms_by_id.clear()

	if arena_level != null:
		if arena_level.get_parent() == self:
			remove_child(arena_level)
		arena_level.queue_free()
	arena_level = null
