class_name ServerArenaRuntime
extends Node

const NetworkServerBroadcastUtilsData := preload("res://net/network_server_broadcast_utils.gd")
const ServerArenaLoadoutAuthorityUtilsData := preload(
	"res://core/server_arena_loadout_authority_utils.gd"
)

var arena_level: ArenaLevelMvp
var arena_spawn_transforms_by_id: Dictionary[StringName, Transform2D] = {}
var player_tanks_by_peer_id: Dictionary[int, Tank] = {}
var peer_id_by_tank_instance_id: Dictionary[int, int] = {}
var spawn_ids_by_peer_id: Dictionary[int, StringName] = {}
var network_server: NetworkServer
var arena_session_state: ArenaSessionState
var next_shell_shot_id: int = 1
var next_kill_event_seq: int = 1
var shot_id_by_shell_instance_id: Dictionary[int, int] = {}
var firing_peer_id_by_shell_instance_id: Dictionary[int, int] = {}
var shell_spec_cache_by_path: Dictionary[String, ShellSpec] = {}


func _ready() -> void:
	Utils.connect_checked(GameplayBus.shell_fired, _on_shell_fired)


func configure_network_server(next_network_server: NetworkServer) -> void:
	network_server = next_network_server


func configure_arena_session(next_arena_session_state: ArenaSessionState) -> void:
	arena_session_state = next_arena_session_state


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
	var is_valid: bool = validation_result.get("valid", false)
	var spawn_count: int = validation_result.get("spawn_count", 0)
	var empty_spawn_id_count: int = validation_result.get("empty_spawn_id_count", 0)
	var duplicate_spawn_ids: PackedStringArray = validation_result.get("duplicate_spawn_ids", [])
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
	if arena_spawn_transforms_by_id.is_empty():
		push_error("[server][arena-runtime] spawn config produced zero spawn transforms")
		_clear_runtime()
		return false
	print(
		(
			"[server][arena-runtime] initialized level=res://levels/arena/arena_level_mvp.tscn count=%d"
			% spawn_count
		)
	)
	return true


func get_spawn_transforms_by_id() -> Dictionary[StringName, Transform2D]:
	return arena_spawn_transforms_by_id.duplicate(true)


func spawn_peer_tank(
	peer_id: int,
	player_name: String,
	tank_id: int,
	spawn_id: StringName,
	spawn_transform: Transform2D
) -> void:
	if arena_level == null:
		push_warning("[server][arena-runtime] spawn ignored: arena level missing")
		return
	if player_tanks_by_peer_id.has(peer_id):
		despawn_peer_tank(peer_id, "REPLACED_EXISTING_TANK")

	var validated_tank_id: int = ServerArenaLoadoutAuthorityUtilsData.resolve_valid_tank_id(tank_id)
	var spawned_tank: Tank = TankManager.create_tank(
		validated_tank_id, TankManager.TankControllerType.DUMMY
	)
	arena_level.add_child(spawned_tank)
	spawned_tank.apply_spawn_state(spawn_transform.origin, spawn_transform.get_rotation())
	player_tanks_by_peer_id[peer_id] = spawned_tank
	peer_id_by_tank_instance_id[spawned_tank.get_instance_id()] = peer_id
	spawn_ids_by_peer_id[peer_id] = spawn_id
	ServerArenaLoadoutAuthorityUtilsData.sync_peer_tank_shell_state(self, peer_id, spawned_tank)
	ServerArenaLoadoutAuthorityUtilsData.send_peer_loadout_state(self, peer_id, spawned_tank)

	print(
		(
			(
				"[server][arena-runtime] tank_spawned peer=%d player=%s "
				+ "spawn_id=%s tank_instance=%s"
			)
			% [peer_id, player_name, spawn_id, str(spawned_tank.get_instance_id())]
		)
	)


func is_peer_tank_dead(peer_id: int) -> bool:
	var spawned_tank: Tank = player_tanks_by_peer_id.get(peer_id)
	if spawned_tank == null:
		return false
	return spawned_tank._health <= 0


func respawn_peer_tank(
	peer_id: int,
	player_name: String,
	tank_id: int,
	spawn_id: StringName,
	spawn_transform: Transform2D
) -> bool:
	if not is_peer_tank_dead(peer_id):
		return false
	spawn_peer_tank(peer_id, player_name, tank_id, spawn_id, spawn_transform)
	print("[server][arena-runtime] tank_respawned peer=%d spawn_id=%s" % [peer_id, spawn_id])
	return true


func despawn_peer_tank(peer_id: int, reason: String) -> void:
	var spawned_tank: Tank = player_tanks_by_peer_id.get(peer_id)
	if spawned_tank != null:
		peer_id_by_tank_instance_id.erase(spawned_tank.get_instance_id())
		spawned_tank.queue_free()
	player_tanks_by_peer_id.erase(peer_id)
	spawn_ids_by_peer_id.erase(peer_id)
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

		if spawned_tank._health > 0:
			_apply_peer_input_intent_to_tank(arena_session_state, peer_id, spawned_tank, peer_state)
		else:
			spawned_tank.reset_input()
		var tank_position: Vector2 = spawned_tank.global_position
		var tank_rotation: float = spawned_tank.global_rotation
		var tank_linear_velocity: Vector2 = spawned_tank.linear_velocity
		var turret_rotation: float = spawned_tank.turret.rotation
		arena_session_state.set_peer_authoritative_state(
			peer_id, tank_position, tank_rotation, tank_linear_velocity, turret_rotation
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
					"turret_rotation": turret_rotation,
					"last_processed_input_tick": int(peer_state.get("last_input_tick", 0)),
				}
			)
		)
	return snapshot_player_states


func _apply_peer_input_intent_to_tank(
	arena_session_state: ArenaSessionState, peer_id: int, spawned_tank: Tank, peer_state: Dictionary
) -> void:
	var left_track_input: float = clamp(float(peer_state.get("input_left_track", 0.0)), -1.0, 1.0)
	var right_track_input: float = clamp(float(peer_state.get("input_right_track", 0.0)), -1.0, 1.0)
	var turret_aim: float = clamp(float(peer_state.get("input_turret_aim", 0.0)), -1.0, 1.0)

	spawned_tank.left_track_input = left_track_input
	spawned_tank.right_track_input = right_track_input
	spawned_tank.turret_rotation_input = turret_aim

	var shell_select_request: Dictionary = arena_session_state.consume_peer_shell_select_request(
		peer_id
	)
	if not shell_select_request.is_empty():
		ServerArenaLoadoutAuthorityUtilsData.handle_peer_shell_select_request(
			self, arena_session_state, peer_id, spawned_tank, shell_select_request
		)

	var fire_request_seq: int = arena_session_state.consume_peer_fire_request_seq(peer_id)
	if fire_request_seq > 0:
		ServerArenaLoadoutAuthorityUtilsData.handle_peer_fire_request(
			self, arena_session_state, peer_id, spawned_tank
		)


func _on_shell_fired(shell: Shell, tank: Tank) -> void:
	if shell == null or tank == null:
		return
	var tank_instance_id: int = tank.get_instance_id()
	if not peer_id_by_tank_instance_id.has(tank_instance_id):
		shell.queue_free()
		return
	if network_server == null:
		shell.queue_free()
		return
	if arena_level == null:
		shell.queue_free()
		return
	var firing_peer_id: int = peer_id_by_tank_instance_id[tank_instance_id]
	var shot_id: int = next_shell_shot_id
	next_shell_shot_id += 1
	var shell_instance_id: int = shell.get_instance_id()
	shot_id_by_shell_instance_id[shell_instance_id] = shot_id
	firing_peer_id_by_shell_instance_id[shell_instance_id] = firing_peer_id
	Utils.connect_checked(shell.impact_resolved, _on_shell_impact_resolved)
	Utils.connect_checked(
		shell.tree_exiting, func() -> void: _on_server_shell_exited(shell_instance_id)
	)
	arena_level.add_child(shell)
	var shell_spec_path: String = ""
	if shell.shell_spec != null:
		shell_spec_path = shell.shell_spec.resource_path
	NetworkServerBroadcastUtilsData.broadcast_arena_shell_spawn(
		network_server,
		network_server.multiplayer.get_peers(),
		shot_id,
		firing_peer_id,
		shell_spec_path,
		shell.global_position,
		shell.velocity,
		shell.rotation
	)


func _on_shell_impact_resolved(
	shell: Shell,
	target_tank: Tank,
	result_type: ShellSpec.ImpactResultType,
	damage: int,
	hit_position: Vector2,
	post_impact_velocity: Vector2,
	post_impact_rotation: float,
	continue_simulation: bool
) -> void:
	if network_server == null or shell == null or target_tank == null:
		return
	var shell_instance_id: int = shell.get_instance_id()
	if not shot_id_by_shell_instance_id.has(shell_instance_id):
		return
	var target_tank_instance_id: int = target_tank.get_instance_id()
	if not peer_id_by_tank_instance_id.has(target_tank_instance_id):
		return
	var target_peer_id: int = peer_id_by_tank_instance_id[target_tank_instance_id]
	var shot_id: int = shot_id_by_shell_instance_id[shell_instance_id]
	var firing_peer_id: int = firing_peer_id_by_shell_instance_id.get(shell_instance_id, 0)
	var remaining_health: int = target_tank._health
	NetworkServerBroadcastUtilsData.broadcast_arena_shell_impact(
		network_server,
		network_server.multiplayer.get_peers(),
		shot_id,
		firing_peer_id,
		target_peer_id,
		int(result_type),
		damage,
		remaining_health,
		hit_position,
		post_impact_velocity,
		post_impact_rotation,
		continue_simulation
	)
	if remaining_health > 0 or damage <= 0:
		return
	var kill_event_seq: int = next_kill_event_seq
	next_kill_event_seq += 1
	NetworkServerBroadcastUtilsData.broadcast_arena_kill_event(
		network_server,
		network_server.multiplayer.get_peers(),
		kill_event_seq,
		firing_peer_id,
		_get_player_name_for_peer(firing_peer_id),
		_get_tank_display_name_for_peer(firing_peer_id),
		_get_shell_short_name(shell),
		target_peer_id,
		_get_player_name_for_peer(target_peer_id),
		_get_tank_display_name_for_peer(target_peer_id)
	)


func _on_server_shell_exited(shell_instance_id: int) -> void:
	shot_id_by_shell_instance_id.erase(shell_instance_id)
	firing_peer_id_by_shell_instance_id.erase(shell_instance_id)


func _exit_tree() -> void:
	_clear_runtime()


func _clear_runtime() -> void:
	for tank: Tank in player_tanks_by_peer_id.values():
		tank.queue_free()
	player_tanks_by_peer_id.clear()
	peer_id_by_tank_instance_id.clear()
	spawn_ids_by_peer_id.clear()
	arena_spawn_transforms_by_id.clear()
	shot_id_by_shell_instance_id.clear()
	firing_peer_id_by_shell_instance_id.clear()
	next_shell_shot_id = 1
	next_kill_event_seq = 1
	shell_spec_cache_by_path.clear()

	if arena_level != null:
		if arena_level.get_parent() == self:
			remove_child(arena_level)
		arena_level.queue_free()
	arena_level = null


func _get_player_name_for_peer(peer_id: int) -> String:
	if arena_session_state == null:
		return str(peer_id)
	var peer_state: Dictionary = arena_session_state.get_peer_state(peer_id)
	var player_name: String = str(peer_state.get("player_name", ""))
	if player_name.is_empty():
		return str(peer_id)
	return player_name


func _get_tank_display_name_for_peer(peer_id: int) -> String:
	var live_tank: Tank = player_tanks_by_peer_id.get(peer_id)
	var tank_spec: TankSpec = null
	if live_tank != null:
		tank_spec = live_tank.tank_spec
	if tank_spec == null and arena_session_state != null:
		var tank_id: int = arena_session_state.get_peer_tank_id(peer_id)
		if TankManager.tank_specs.has(tank_id):
			tank_spec = TankManager.tank_specs[tank_id]
	if tank_spec == null:
		return "TANK"
	var display_name: String = tank_spec.display_name.strip_edges()
	if not display_name.is_empty():
		return display_name
	var full_name: String = tank_spec.full_name.strip_edges()
	if not full_name.is_empty():
		return full_name
	return "TANK"


func _get_shell_short_name(shell: Shell) -> String:
	if shell == null or shell.shell_spec == null:
		return "SHELL"
	var shell_name: String = shell.shell_spec.shell_name.strip_edges()
	if shell_name.is_empty():
		return "SHELL"
	var shell_name_parts: PackedStringArray = shell_name.split(" ", false)
	if shell_name_parts.is_empty():
		return shell_name
	return shell_name_parts[0]
