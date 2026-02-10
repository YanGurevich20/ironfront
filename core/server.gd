class_name Server
extends Node

const ServerArenaRuntimeScript := preload("res://core/server_arena_runtime.gd")

@export var listen_port: int = 7000
@export var max_clients: int = 32
@export var tick_rate_hz: int = 30
@export var arena_max_players: int = 10
@export var arena_level_scene: PackedScene = preload("res://levels/arena/arena_level_mvp.tscn")

var tick_count: int = 0
var arena_session_state: ArenaSessionState
var server_arena_runtime: ServerArenaRuntime
var arena_spawn_transforms_by_id: Dictionary = {}

@onready var network_server: NetworkServer = %Network


func _ready() -> void:
	_apply_cli_args()
	var runtime_started: bool = _start_arena_runtime()
	if not runtime_started:
		get_tree().quit(1)
		return
	arena_session_state = ArenaSessionState.new(arena_max_players)
	network_server.configure_arena_session(arena_session_state)
	network_server.configure_arena_spawn_pool(arena_spawn_transforms_by_id)
	network_server.configure_tick_rate(tick_rate_hz)
	Utils.connect_checked(network_server.arena_join_succeeded, _on_arena_join_succeeded)
	Utils.connect_checked(network_server.arena_peer_removed, _on_arena_peer_removed)
	var server_started: bool = network_server.start_server(listen_port, max_clients)
	if not server_started:
		get_tree().quit(1)
	print(
		(
			"[server][arena] global_session_started created_at=%d max_players=%d"
			% [arena_session_state.created_unix_time, arena_session_state.max_players]
		)
	)
	_configure_physics_tick_loop()


func _start_arena_runtime() -> bool:
	server_arena_runtime = ServerArenaRuntimeScript.new()
	add_child(server_arena_runtime)
	var initialized: bool = server_arena_runtime.initialize_runtime(arena_level_scene)
	if not initialized:
		server_arena_runtime.queue_free()
		server_arena_runtime = null
		return false
	arena_spawn_transforms_by_id = server_arena_runtime.get_spawn_transforms_by_id()
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
	peer_id: int, player_name: String, spawn_id: StringName, spawn_transform: Transform2D
) -> void:
	if server_arena_runtime == null:
		return
	server_arena_runtime.spawn_peer_tank(peer_id, player_name, spawn_id, spawn_transform)


func _on_arena_peer_removed(peer_id: int, reason: String) -> void:
	if server_arena_runtime == null:
		return
	server_arena_runtime.despawn_peer_tank(peer_id, reason)


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
		var uptime_seconds: int = int(tick_count / float(tick_rate_hz))
		var arena_player_count: int = 0
		if arena_session_state != null:
			arena_player_count = arena_session_state.get_player_count()
		var sync_metrics: Dictionary = network_server.get_debug_sync_metrics()
		print(
			(
				(
					"[server] uptime=%ds peers=%d arena_players=%d "
					+ "sync{interval=%d active_tick_calls=%d gate_hits=%d "
					+ "rx=%d applied=%d snapshots=%d last_tick=%d}"
				)
				% [
					uptime_seconds,
					multiplayer.get_peers().size(),
					arena_player_count,
					int(sync_metrics.get("snapshot_interval_ticks", -1)),
					int(sync_metrics.get("total_on_server_tick_active_calls", -1)),
					int(sync_metrics.get("total_snapshot_gate_hits", -1)),
					int(sync_metrics.get("total_input_messages_received", -1)),
					int(sync_metrics.get("total_input_messages_applied", -1)),
					int(sync_metrics.get("total_snapshots_broadcast", -1)),
					int(sync_metrics.get("last_snapshot_tick", -1)),
				]
			)
		)
