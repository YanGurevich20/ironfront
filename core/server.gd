class_name Server
extends Node

const ServerArenaRuntimeScript := preload("res://core/server_arena_runtime.gd")

@export var listen_port: int = 7000
@export var max_clients: int = 32
@export var tick_rate_hz: int = 60
@export var arena_max_players: int = 10
@export var arena_level_scene: PackedScene = preload("res://levels/arena/arena_level_mvp.tscn")

var tick_count: int = 0
var arena_session_state: ArenaSessionState
var server_arena_runtime: ServerArenaRuntime
var arena_spawn_transforms_by_id: Dictionary[StringName, Transform2D] = {}
var metrics_logger: ServerMetricsLogger

@onready var network_server: NetworkServer = %Network


func _ready() -> void:
	_apply_cli_args()
	var runtime_started: bool = _start_arena_runtime()
	if not runtime_started:
		get_tree().quit(1)
		return
	arena_spawn_transforms_by_id = server_arena_runtime.get_spawn_transforms_by_id()
	if arena_spawn_transforms_by_id.is_empty():
		push_error("[server][arena] startup aborted: spawn pool empty after runtime initialization")
		get_tree().quit(1)
		return
	arena_session_state = ArenaSessionState.new(arena_max_players)
	network_server.configure_arena_session(arena_session_state)
	server_arena_runtime.configure_arena_session(arena_session_state)
	network_server.configure_arena_spawn_pool(arena_spawn_transforms_by_id)
	print("[server][arena] startup_spawn_pool count=%d" % arena_spawn_transforms_by_id.size())
	network_server.configure_tick_rate(tick_rate_hz)
	server_arena_runtime.configure_network_server(network_server)
	Utils.connect_checked(network_server.arena_join_succeeded, _on_arena_join_succeeded)
	Utils.connect_checked(network_server.arena_peer_removed, _on_arena_peer_removed)
	Utils.connect_checked(network_server.arena_respawn_requested, _on_arena_respawn_requested)
	var server_started: bool = network_server.start_server(listen_port, max_clients)
	if not server_started:
		get_tree().quit(1)
	print(
		(
			"[server][arena] global_session_started created_at=%d max_players=%d"
			% [arena_session_state.created_unix_time, arena_session_state.max_players]
		)
	)
	metrics_logger = ServerMetricsLogger.new(self)
	_configure_physics_tick_loop()


func _start_arena_runtime() -> bool:
	server_arena_runtime = ServerArenaRuntimeScript.new()
	add_child(server_arena_runtime)
	var initialized: bool = server_arena_runtime.initialize_runtime(arena_level_scene)
	if not initialized:
		server_arena_runtime.queue_free()
		server_arena_runtime = null
		return false
	return true


func _apply_cli_args() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for arg: String in args:
		if arg.begins_with("--port="):
			var port_value: int = int(arg.trim_prefix("--port="))
			if port_value > 0:
				listen_port = port_value


func _configure_physics_tick_loop() -> void:
	Engine.physics_ticks_per_second = max(1, tick_rate_hz)
	set_physics_process(true)
	print("[server] physics tick loop configured at %d Hz" % Engine.physics_ticks_per_second)


func _on_arena_join_succeeded(
	peer_id: int,
	player_name: String,
	tank_id: int,
	spawn_id: StringName,
	spawn_transform: Transform2D
) -> void:
	if server_arena_runtime == null:
		return
	server_arena_runtime.spawn_peer_tank(peer_id, player_name, tank_id, spawn_id, spawn_transform)


func _on_arena_peer_removed(peer_id: int, reason: String) -> void:
	if server_arena_runtime == null:
		return
	server_arena_runtime.despawn_peer_tank(peer_id, reason)


func _on_arena_respawn_requested(peer_id: int) -> void:
	var respawn_context: Dictionary = _build_respawn_context(peer_id)
	if not respawn_context.get("valid", false):
		return
	var spawn_id: StringName = respawn_context.get("spawn_id", StringName())
	var spawn_transform: Transform2D = respawn_context.get("spawn_transform", Transform2D.IDENTITY)
	var player_name: String = respawn_context.get("player_name", "")
	var tank_id: int = int(respawn_context.get("tank_id", ArenaSessionState.DEFAULT_TANK_ID))
	var reset_loadout: bool = arena_session_state._reset_peer_loadout_to_entry_state(peer_id)
	if not reset_loadout:
		push_warning("[server][arena] respawn_loadout_reset_failed peer=%d" % peer_id)
	var respawned: bool = server_arena_runtime.respawn_peer_tank(
		peer_id, player_name, tank_id, spawn_id, spawn_transform
	)
	if not respawned:
		return
	arena_session_state.clear_peer_control_intent(peer_id)
	arena_session_state.set_peer_authoritative_state(
		peer_id, spawn_transform.origin, spawn_transform.get_rotation(), Vector2.ZERO, 0.0
	)
	network_server.broadcast_arena_respawn(
		peer_id, player_name, spawn_transform.origin, spawn_transform.get_rotation()
	)
	print("[server][arena] player_respawned peer=%d spawn_id=%s" % [peer_id, spawn_id])


func _build_respawn_context(peer_id: int) -> Dictionary:
	if arena_session_state == null or server_arena_runtime == null:
		return {"valid": false}
	if (
		not arena_session_state.has_peer(peer_id)
		or not server_arena_runtime.is_peer_tank_dead(peer_id)
	):
		return {"valid": false}
	var random_spawn: Dictionary = _pick_random_spawn()
	if random_spawn.is_empty():
		push_warning("[server][arena] respawn rejected peer=%d reason=NO_SPAWN_AVAILABLE" % peer_id)
		return {"valid": false}
	var spawn_id: StringName = random_spawn.get("spawn_id", StringName())
	var spawn_transform: Transform2D = random_spawn.get("spawn_transform", Transform2D.IDENTITY)
	var peer_state: Dictionary = arena_session_state.get_peer_state(peer_id)
	return {
		"valid": true,
		"spawn_id": spawn_id,
		"spawn_transform": spawn_transform,
		"player_name": str(peer_state.get("player_name", "")),
		"tank_id": arena_session_state.get_peer_tank_id(peer_id),
	}


func _pick_random_spawn() -> Dictionary:
	var available_spawn_ids: Array[StringName] = arena_spawn_transforms_by_id.keys()
	if available_spawn_ids.is_empty():
		return {}
	available_spawn_ids.shuffle()
	var selected_spawn_id: StringName = available_spawn_ids[0]
	return {
		"spawn_id": selected_spawn_id,
		"spawn_transform": arena_spawn_transforms_by_id[selected_spawn_id],
	}


func _physics_process(delta: float) -> void:
	tick_count += 1
	var authoritative_player_states: Array[Dictionary] = []
	if server_arena_runtime != null and arena_session_state != null:
		authoritative_player_states = server_arena_runtime.step_authoritative_runtime(
			arena_session_state
		)
	network_server.set_authoritative_player_states(authoritative_player_states)
	network_server.on_server_tick(tick_count, delta)
	if tick_count % (tick_rate_hz * 5) == 0:
		metrics_logger.log_periodic()
