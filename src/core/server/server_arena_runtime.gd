class_name ServerArenaRuntime
extends Node

var arena_level: ArenaLevelMvp
var arena_spawn_transforms_by_id: Dictionary[StringName, Transform2D] = {}
var actor_tanks_by_id: Dictionary[int, Tank] = {}
var actor_metadata_by_id: Dictionary[int, Dictionary] = {}
var actor_id_by_tank_instance_id: Dictionary[int, int] = {}
var actor_spawn_ids_by_id: Dictionary[int, StringName] = {}
var network_server: NetworkServer
var arena_session_state: ArenaSessionState
var next_shell_shot_id: int = 1
var next_kill_event_seq: int = 1
var shot_id_by_shell_instance_id: Dictionary[int, int] = {}
var firing_actor_id_by_shell_instance_id: Dictionary[int, int] = {}
var shell_spec_cache_by_path: Dictionary[String, ShellSpec] = {}
var bot_count: int = 0
var bot_respawn_delay_seconds: float = 5.0
var next_bot_actor_id: int = ServerArenaActorUtils.BOT_ACTOR_ID_START
var pending_bot_respawns: Array[Dictionary] = []


func _ready() -> void:
	Utils.connect_checked(GameplayBus.shell_fired, _on_shell_fired)
	Utils.connect_checked(GameplayBus.tank_destroyed, _on_tank_destroyed)


func configure_network_server(next_network_server: NetworkServer) -> void:
	network_server = next_network_server


func configure_arena_session(next_arena_session_state: ArenaSessionState) -> void:
	arena_session_state = next_arena_session_state


func configure_bot_settings(next_bot_count: int, next_bot_respawn_delay_seconds: float) -> void:
	bot_count = max(0, next_bot_count)
	bot_respawn_delay_seconds = max(0.0, next_bot_respawn_delay_seconds)


func initialize_runtime(arena_level_packed_scene: PackedScene) -> bool:
	ServerArenaActorUtils.clear_runtime(self)
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
		ServerArenaActorUtils.clear_runtime(self)
		return false

	arena_spawn_transforms_by_id = arena_level.get_spawn_transforms_by_id().duplicate(true)
	if arena_spawn_transforms_by_id.is_empty():
		push_error("[server][arena-runtime] spawn config produced zero spawn transforms")
		ServerArenaActorUtils.clear_runtime(self)
		return false

	ServerArenaActorUtils.spawn_initial_bots(self)
	print(
		(
			(
				"[server][arena-runtime] initialized level=res://src/levels/arena/arena_level_mvp.tscn "
				+ "count=%d bots=%d"
			)
			% [spawn_count, bot_count]
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
	if actor_tanks_by_id.has(peer_id):
		despawn_peer_tank(peer_id, "REPLACED_EXISTING_TANK")

	var validated_tank_id: int = ServerArenaLoadoutAuthorityUtils.resolve_valid_tank_id(tank_id)
	var spawned_tank: Tank = TankManager.create_tank(
		validated_tank_id, TankManager.TankControllerType.DUMMY
	)
	spawned_tank.add_to_group("arena_human_player")
	(
		ServerArenaActorUtils
		.register_actor(
			self,
			peer_id,
			spawned_tank,
			spawn_id,
			{
				"is_bot": false,
				"player_name": player_name,
				"tank_id": validated_tank_id,
			}
		)
	)
	spawned_tank.apply_spawn_state(spawn_transform.origin, spawn_transform.get_rotation())
	ServerArenaLoadoutAuthorityUtils.sync_peer_tank_shell_state(self, peer_id, spawned_tank)
	ServerArenaLoadoutAuthorityUtils.send_peer_loadout_state(self, peer_id, spawned_tank)

	print(
		(
			(
				"[server][arena-runtime] tank_spawned actor=%d player=%s "
				+ "spawn_id=%s tank_instance=%s"
			)
			% [peer_id, player_name, spawn_id, str(spawned_tank.get_instance_id())]
		)
	)


func is_peer_tank_dead(peer_id: int) -> bool:
	var spawned_tank: Tank = actor_tanks_by_id.get(peer_id)
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
	print("[server][arena-runtime] tank_respawned actor=%d spawn_id=%s" % [peer_id, spawn_id])
	return true


func despawn_peer_tank(peer_id: int, reason: String) -> void:
	ServerArenaActorUtils.despawn_actor(self, peer_id, reason)


func step_authoritative_runtime(
	next_arena_session_state: ArenaSessionState, delta: float
) -> Array[Dictionary]:
	var snapshot_actor_states: Array[Dictionary] = []

	ServerArenaActorUtils.update_pending_bot_respawns(self, delta)

	var peer_ids: Array[int] = next_arena_session_state.get_peer_ids()
	for peer_id: int in peer_ids:
		var spawned_tank: Tank = actor_tanks_by_id.get(peer_id)
		if spawned_tank == null:
			continue
		var peer_state: Dictionary = next_arena_session_state.get_peer_state(peer_id)
		if peer_state.is_empty():
			spawned_tank.reset_input()
			continue

		if spawned_tank._health > 0:
			_apply_peer_input_intent_to_tank(
				next_arena_session_state, peer_id, spawned_tank, peer_state
			)
		else:
			spawned_tank.reset_input()
		_update_peer_authoritative_state(next_arena_session_state, peer_id, spawned_tank)

	var actor_ids: Array[int] = actor_tanks_by_id.keys()
	actor_ids.sort()
	for actor_id: int in actor_ids:
		var actor_tank: Tank = actor_tanks_by_id.get(actor_id)
		if actor_tank == null:
			continue
		var actor_metadata: Dictionary = actor_metadata_by_id.get(actor_id, {})
		var is_bot: bool = bool(actor_metadata.get("is_bot", false))
		var player_name: String = ServerArenaActorUtils.get_actor_player_name(self, actor_id)
		var last_processed_input_tick: int = 0
		if not is_bot:
			var peer_state: Dictionary = next_arena_session_state.get_peer_state(actor_id)
			last_processed_input_tick = int(peer_state.get("last_input_tick", 0))
		(
			snapshot_actor_states
			. append(
				{
					"peer_id": actor_id,
					"player_name": player_name,
					"position": actor_tank.global_position,
					"rotation": actor_tank.global_rotation,
					"linear_velocity": actor_tank.linear_velocity,
					"turret_rotation": actor_tank.turret.rotation,
					"last_processed_input_tick": last_processed_input_tick,
					"is_bot": is_bot,
					"is_alive": actor_tank._health > 0,
				}
			)
		)
	return snapshot_actor_states


func _update_peer_authoritative_state(
	next_arena_session_state: ArenaSessionState, peer_id: int, spawned_tank: Tank
) -> void:
	next_arena_session_state.set_peer_authoritative_state(
		peer_id,
		spawned_tank.global_position,
		spawned_tank.global_rotation,
		spawned_tank.linear_velocity,
		spawned_tank.turret.rotation
	)


func _apply_peer_input_intent_to_tank(
	next_arena_session_state: ArenaSessionState,
	peer_id: int,
	spawned_tank: Tank,
	peer_state: Dictionary
) -> void:
	var left_track_input: float = clamp(float(peer_state.get("input_left_track", 0.0)), -1.0, 1.0)
	var right_track_input: float = clamp(float(peer_state.get("input_right_track", 0.0)), -1.0, 1.0)
	var turret_aim: float = clamp(float(peer_state.get("input_turret_aim", 0.0)), -1.0, 1.0)

	spawned_tank.left_track_input = left_track_input
	spawned_tank.right_track_input = right_track_input
	spawned_tank.turret_rotation_input = turret_aim

	var shell_select_request: Dictionary = (
		next_arena_session_state.consume_peer_shell_select_request(peer_id)
	)
	if not shell_select_request.is_empty():
		ServerArenaLoadoutAuthorityUtils.handle_peer_shell_select_request(
			self, next_arena_session_state, peer_id, spawned_tank, shell_select_request
		)

	var fire_request_seq: int = next_arena_session_state.consume_peer_fire_request_seq(peer_id)
	if fire_request_seq > 0:
		ServerArenaLoadoutAuthorityUtils.handle_peer_fire_request(
			self, next_arena_session_state, peer_id, spawned_tank
		)


func _on_shell_fired(shell: Shell, tank: Tank) -> void:
	var tank_instance_id: int = tank.get_instance_id()
	if not actor_id_by_tank_instance_id.has(tank_instance_id):
		shell.queue_free()
		return
	var firing_actor_id: int = actor_id_by_tank_instance_id[tank_instance_id]
	var shot_id: int = next_shell_shot_id
	next_shell_shot_id += 1
	var shell_instance_id: int = shell.get_instance_id()
	shot_id_by_shell_instance_id[shell_instance_id] = shot_id
	firing_actor_id_by_shell_instance_id[shell_instance_id] = firing_actor_id
	Utils.connect_checked(shell.impact_resolved, _on_shell_impact_resolved)
	Utils.connect_checked(
		shell.tree_exiting, func() -> void: _on_server_shell_exited(shell_instance_id)
	)
	arena_level.add_child(shell)
	var shell_spec_path: String = shell.shell_spec.resource_path if shell.shell_spec != null else ""
	NetworkServerBroadcastUtils.broadcast_arena_shell_spawn(
		network_server,
		network_server.multiplayer.get_peers(),
		shot_id,
		firing_actor_id,
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
	var shell_instance_id: int = shell.get_instance_id()
	if not shot_id_by_shell_instance_id.has(shell_instance_id):
		return
	var target_tank_instance_id: int = target_tank.get_instance_id()
	if not actor_id_by_tank_instance_id.has(target_tank_instance_id):
		return
	var target_actor_id: int = actor_id_by_tank_instance_id[target_tank_instance_id]
	var shot_id: int = shot_id_by_shell_instance_id[shell_instance_id]
	var firing_actor_id: int = firing_actor_id_by_shell_instance_id.get(shell_instance_id, 0)
	var remaining_health: int = target_tank._health
	NetworkServerBroadcastUtils.broadcast_arena_shell_impact(
		network_server,
		network_server.multiplayer.get_peers(),
		shot_id,
		firing_actor_id,
		target_actor_id,
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
	NetworkServerBroadcastUtils.broadcast_arena_kill_event(
		network_server,
		network_server.multiplayer.get_peers(),
		kill_event_seq,
		firing_actor_id,
		ServerArenaActorUtils.get_actor_player_name(self, firing_actor_id),
		ServerArenaActorUtils.get_actor_tank_display_name(self, firing_actor_id),
		shell.shell_spec.shell_name,
		target_actor_id,
		ServerArenaActorUtils.get_actor_player_name(self, target_actor_id),
		ServerArenaActorUtils.get_actor_tank_display_name(self, target_actor_id)
	)


func _on_tank_destroyed(tank: Tank) -> void:
	var tank_instance_id: int = tank.get_instance_id()
	if not actor_id_by_tank_instance_id.has(tank_instance_id):
		return
	var actor_id: int = actor_id_by_tank_instance_id[tank_instance_id]
	var actor_metadata: Dictionary = actor_metadata_by_id.get(actor_id, {})
	if not bool(actor_metadata.get("is_bot", false)):
		return
	ServerArenaActorUtils.schedule_bot_respawn(self, actor_id)


func _on_server_shell_exited(shell_instance_id: int) -> void:
	shot_id_by_shell_instance_id.erase(shell_instance_id)
	firing_actor_id_by_shell_instance_id.erase(shell_instance_id)


func _exit_tree() -> void:
	ServerArenaActorUtils.clear_runtime(self)
