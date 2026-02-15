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
	Utils.connect_checked(network_server.arena_leave_requested, _on_arena_leave_requested)
	Utils.connect_checked(network_server.arena_peer_disconnected, _on_arena_peer_disconnected)
	Utils.connect_checked(
		network_server.arena_input_intent_received, _on_arena_input_intent_received
	)
	Utils.connect_checked(network_server.arena_fire_requested, _on_arena_fire_requested)
	Utils.connect_checked(
		network_server.arena_shell_select_requested, _on_arena_shell_select_requested
	)
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
	peer_id: int,
	player_name: String,
	requested_tank_id: int,
	requested_shell_loadout_by_path: Dictionary,
	requested_selected_shell_path: String
) -> void:
	if arena_session_state.has_peer(peer_id):
		_remove_arena_peer(peer_id, "REJOIN_REQUEST")
	var cleaned_player_name: String = player_name.strip_edges()
	if cleaned_player_name.is_empty():
		print("[server][join] reject_join_arena peer=%d reason=INVALID_PLAYER_NAME" % peer_id)
		network_server.reject_arena_join(peer_id, "INVALID PLAYER NAME")
		return
	var join_result: Dictionary = arena_session_state.try_join_peer(
		peer_id,
		cleaned_player_name,
		requested_tank_id,
		requested_shell_loadout_by_path,
		requested_selected_shell_path
	)
	var join_message: String = str(join_result.get("message", "JOIN FAILED"))
	if not join_result.get("success", false):
		print("[server][join] reject_join_arena peer=%d reason=%s" % [peer_id, join_message])
		network_server.reject_arena_join(peer_id, join_message)
		return
	var tank_id: int = int(join_result.get("tank_id", ArenaSessionState.DEFAULT_TANK_ID))
	var join_spawn_result: Dictionary = ServerArenaActorUtils.spawn_peer_tank_at_random(
		server_arena_runtime, peer_id, cleaned_player_name, tank_id
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


func _on_arena_leave_requested(peer_id: int) -> void:
	var removed: bool = _remove_arena_peer(peer_id, "CLIENT_REQUEST")
	var leave_message: String = "LEFT ARENA" if removed else "NOT IN ARENA"
	network_server.complete_arena_leave(peer_id, leave_message)


func _on_arena_peer_disconnected(peer_id: int) -> void:
	_remove_arena_peer(peer_id, "PEER_DISCONNECTED")


func _remove_arena_peer(peer_id: int, reason: String) -> bool:
	var remove_result: Dictionary = arena_session_state.remove_peer(peer_id, reason)
	if not remove_result.get("removed", false):
		return false
	server_arena_runtime.despawn_peer_tank(peer_id, reason)
	network_server.broadcast_state_snapshot_now()
	print("[server][arena] peer_removed_cleanup peer=%d reason=%s" % [peer_id, reason])
	return true


func _on_arena_input_intent_received(
	peer_id: int,
	input_tick: int,
	left_track_input: float,
	right_track_input: float,
	turret_aim: float
) -> void:
	if not arena_session_state.has_peer(peer_id):
		return
	if input_tick <= 0:
		return
	var is_too_far_future: bool = (
		input_tick
		> (
			arena_session_state.get_peer_last_input_tick(peer_id)
			+ MultiplayerProtocol.MAX_INPUT_FUTURE_TICKS
		)
	)
	if is_too_far_future:
		print("[server][sync][input] ignored_far_future peer=%d tick=%d" % [peer_id, input_tick])
		return
	var received_msec: int = Time.get_ticks_msec()
	var accepted: bool = arena_session_state.set_peer_input_intent(
		peer_id,
		input_tick,
		clamp(left_track_input, -1.0, 1.0),
		clamp(right_track_input, -1.0, 1.0),
		clamp(turret_aim, -1.0, 1.0),
		received_msec
	)
	if not accepted:
		print("[server][sync][input] ignored_non_monotonic peer=%d tick=%d" % [peer_id, input_tick])
		return
	network_server.mark_input_applied()


func _on_arena_fire_requested(peer_id: int, fire_request_seq: int) -> void:
	if not arena_session_state.has_peer(peer_id):
		return
	var received_msec: int = Time.get_ticks_msec()
	var accepted: bool = arena_session_state.queue_peer_fire_request(
		peer_id, fire_request_seq, received_msec
	)
	if not accepted:
		print(
			(
				"[server][sync][fire] ignored_non_monotonic peer=%d seq=%d"
				% [peer_id, fire_request_seq]
			)
		)
		return
	network_server.mark_fire_request_applied()


func _on_arena_shell_select_requested(
	peer_id: int, shell_select_seq: int, shell_spec_path: String
) -> void:
	if not arena_session_state.has_peer(peer_id):
		return
	var received_msec: int = Time.get_ticks_msec()
	var accepted: bool = arena_session_state.queue_peer_shell_select_request(
		peer_id, shell_select_seq, shell_spec_path, received_msec
	)
	if not accepted:
		print(
			(
				(
					"[server][sync][shell_select] ignored_non_monotonic_or_invalid "
					+ "peer=%d seq=%d path=%s"
				)
				% [peer_id, shell_select_seq, shell_spec_path]
			)
		)


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
