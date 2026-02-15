class_name Server
extends Node

@export_range(1, 65535, 1) var listen_port: int = 7_000
@export var max_clients: int = 32
@export var tick_rate_hz: int = 60
@export var arena_max_players: int = 10
@export var arena_bot_count: int = 2
@export var arena_bot_respawn_delay_seconds: float = 5.0
@export var arena_level_scene: PackedScene = preload("res://src/levels/arena/arena_level_mvp.tscn")

var tick_count: int = 0
var arena_session_state: ArenaSessionState
var metrics_logger: ServerMetricsLogger

@onready var network_server: NetworkServer = %Network
@onready var server_arena_runtime: ServerArenaRuntime = %ArenaRuntime


func _ready() -> void:
	_apply_cli_args()
	server_arena_runtime.configure_bot_settings(arena_bot_count, arena_bot_respawn_delay_seconds)
	if not server_arena_runtime.initialize_runtime(arena_level_scene):
		get_tree().quit(1)
		return
	var arena_spawn_transforms_by_id: Dictionary[StringName, Transform2D] = (
		server_arena_runtime.get_spawn_transforms_by_id()
	)
	if arena_spawn_transforms_by_id.is_empty():
		push_error("[server][arena] startup aborted: spawn pool empty after runtime initialization")
		get_tree().quit(1)
		return
	arena_session_state = ArenaSessionState.new(arena_max_players)
	network_server.configure_arena_session(arena_session_state)
	server_arena_runtime.configure_arena_session(arena_session_state)
	print("[server][arena] startup_spawn_pool count=%d" % arena_spawn_transforms_by_id.size())
	network_server.configure_tick_rate(tick_rate_hz)
	server_arena_runtime.configure_network_server(network_server)
	Utils.connect_checked(network_server.arena_join_requested, _on_arena_join_requested)
	Utils.connect_checked(network_server.arena_peer_removed, _on_arena_peer_removed)
	Utils.connect_checked(network_server.arena_respawn_requested, _on_arena_respawn_requested)
	if not network_server.start_server(listen_port, max_clients):
		get_tree().quit(1)
		return
	print(
		(
			"[server][arena] global_session_started created_at=%d max_players=%d"
			% [arena_session_state.created_unix_time, arena_session_state.max_players]
		)
	)
	metrics_logger = ServerMetricsLogger.new(self)
	Engine.physics_ticks_per_second = tick_rate_hz
	print("[server] physics tick loop configured at %d Hz" % Engine.physics_ticks_per_second)


func _apply_cli_args() -> void:
	var client_args: Dictionary = Utils.get_parsed_cmdline_user_args()
	listen_port = max(0, int(client_args.get("port", listen_port)))
	arena_bot_count = max(0, int(client_args.get("bot-count", arena_bot_count)))
	arena_bot_respawn_delay_seconds = max(
		0.0, float(client_args.get("bot-respawn-delay", arena_bot_respawn_delay_seconds))
	)


func _on_arena_join_requested(
	peer_id: int, player_name: String, tank_id: int, join_message: String
) -> void:
	var join_spawn_result: Dictionary = ServerArenaActorUtils.spawn_peer_tank_at_random(
		server_arena_runtime, peer_id, player_name, tank_id
	)
	if not join_spawn_result.get("success", false):
		arena_session_state.remove_peer(peer_id, "NO_SPAWN_AVAILABLE")
		network_server.reject_arena_join(peer_id, "NO SPAWN AVAILABLE")
		return
	var spawn_id: StringName = join_spawn_result.get("spawn_id", StringName())
	var spawn_transform: Transform2D = join_spawn_result.get(
		"spawn_transform", Transform2D.IDENTITY
	)
	arena_session_state.set_peer_authoritative_state(
		peer_id, spawn_transform.origin, spawn_transform.get_rotation(), Vector2.ZERO
	)
	network_server.complete_arena_join(
		peer_id, join_message, spawn_transform.origin, spawn_transform.get_rotation()
	)
	print("[server][arena] player_joined peer=%d spawn_id=%s" % [peer_id, spawn_id])


func _on_arena_peer_removed(peer_id: int, reason: String) -> void:
	server_arena_runtime.despawn_peer_tank(peer_id, reason)


func _on_arena_respawn_requested(peer_id: int) -> void:
	if not arena_session_state.has_peer(peer_id):
		return
	var peer_state: Dictionary = arena_session_state.get_peer_state(peer_id)
	var player_name: String = str(peer_state.get("player_name", ""))
	var tank_id: int = arena_session_state.get_peer_tank_id(peer_id)
	var respawn_result: Dictionary = ServerArenaActorUtils.respawn_peer_tank_at_random(
		server_arena_runtime, peer_id, player_name, tank_id
	)
	if not respawn_result.get("success", false):
		var reason: String = str(respawn_result.get("reason", "RESPAWN_FAILED"))
		if reason == "NO_SPAWN_AVAILABLE":
			push_warning("[server][arena] respawn rejected peer=%d reason=%s" % [peer_id, reason])
		return
	var spawn_id: StringName = respawn_result.get("spawn_id", StringName())
	var spawn_transform: Transform2D = respawn_result.get("spawn_transform", Transform2D.IDENTITY)
	var reset_loadout: bool = arena_session_state._reset_peer_loadout_to_entry_state(peer_id)
	if not reset_loadout:
		push_warning("[server][arena] respawn_loadout_reset_failed peer=%d" % peer_id)
	arena_session_state.clear_peer_control_intent(peer_id)
	arena_session_state.set_peer_authoritative_state(
		peer_id, spawn_transform.origin, spawn_transform.get_rotation(), Vector2.ZERO, 0.0
	)
	network_server.broadcast_arena_respawn(
		peer_id, player_name, spawn_transform.origin, spawn_transform.get_rotation()
	)
	print("[server][arena] player_respawned peer=%d spawn_id=%s" % [peer_id, spawn_id])


func _physics_process(delta: float) -> void:
	tick_count += 1
	var authoritative_player_states: Array[Dictionary] = (
		server_arena_runtime.step_authoritative_runtime(arena_session_state, delta)
	)
	network_server.set_authoritative_player_states(authoritative_player_states)
	network_server.on_server_tick(tick_count, delta)
	metrics_logger.log_periodic()
