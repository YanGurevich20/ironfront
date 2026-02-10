class_name Server
extends Node

@export var listen_port: int = 7000
@export var max_clients: int = 32
@export var tick_rate_hz: int = 30
@export var arena_max_players: int = 10
@export var arena_level_scene: PackedScene = preload("res://levels/arena/arena_level_mvp.tscn")

var tick_timer: Timer
var tick_count: int = 0
var arena_session_state: ArenaSessionState
var arena_spawn_transforms_by_id: Dictionary = {}

@onready var network_server: NetworkServer = %Network


func _ready() -> void:
	_apply_cli_args()
	var spawn_pool_loaded: bool = _load_and_validate_arena_spawn_pool()
	if not spawn_pool_loaded:
		get_tree().quit(1)
		return
	arena_session_state = ArenaSessionState.new(arena_max_players)
	network_server.configure_arena_session(arena_session_state)
	network_server.configure_arena_spawn_pool(arena_spawn_transforms_by_id)
	var server_started: bool = network_server.start_server(listen_port, max_clients)
	if not server_started:
		get_tree().quit(1)
	print(
		(
			"[server][arena] global_session_started created_at=%d max_players=%d"
			% [arena_session_state.created_unix_time, arena_session_state.max_players]
		)
	)
	_start_tick_loop()


func _load_and_validate_arena_spawn_pool() -> bool:
	if arena_level_scene == null:
		push_error("[server][arena] missing arena_level_scene")
		return false

	var arena_level_node: Node = arena_level_scene.instantiate()
	var arena_level: ArenaLevelMvp = arena_level_node as ArenaLevelMvp
	if arena_level == null:
		push_error("[server][arena] arena level scene root must use ArenaLevelMvp script")
		arena_level_node.queue_free()
		return false

	add_child(arena_level)

	var validation_result: Dictionary = arena_level.validate_spawn_markers()
	var is_valid: bool = bool(validation_result.get("valid", false))
	var spawn_count: int = int(validation_result.get("spawn_count", 0))
	var empty_spawn_id_count: int = int(validation_result.get("empty_spawn_id_count", 0))
	var duplicate_spawn_ids: Array = validation_result.get("duplicate_spawn_ids", [])
	if not is_valid:
		push_error(
			(
				"[server][arena] invalid spawn config count=%d empty_ids=%d duplicates=%s"
				% [spawn_count, empty_spawn_id_count, duplicate_spawn_ids]
			)
		)
		remove_child(arena_level)
		arena_level.queue_free()
		return false

	arena_spawn_transforms_by_id = arena_level.get_spawn_transforms_by_id()
	print(
		(
			"[server][arena] loaded_spawn_pool level=res://levels/arena/arena_level_mvp.tscn count=%d"
			% spawn_count
		)
	)

	remove_child(arena_level)
	arena_level.queue_free()
	return true


func _apply_cli_args() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for arg: String in args:
		if arg.begins_with("--port="):
			var port_value: int = int(arg.trim_prefix("--port="))
			if port_value > 0:
				listen_port = port_value


func _start_tick_loop() -> void:
	tick_timer = Timer.new()
	tick_timer.one_shot = false
	tick_timer.wait_time = 1.0 / float(tick_rate_hz)
	add_child(tick_timer)
	Utils.connect_checked(tick_timer.timeout, _on_tick)
	tick_timer.start()
	print("[server] tick loop started at %d Hz" % tick_rate_hz)


func _on_tick() -> void:
	tick_count += 1
	if tick_count % tick_rate_hz == 0:
		var uptime_seconds: int = int(tick_count / float(tick_rate_hz))
		var arena_player_count: int = 0
		if arena_session_state != null:
			arena_player_count = arena_session_state.get_player_count()
		print(
			(
				"[server] uptime=%ds peers=%d arena_players=%d"
				% [uptime_seconds, multiplayer.get_peers().size(), arena_player_count]
			)
		)
