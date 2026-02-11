class_name NetworkClient
extends Node

signal join_status_changed(message: String, is_error: bool)
signal join_arena_completed(success: bool, message: String)
signal state_snapshot_received(server_tick: int, player_states: Array)
signal arena_shell_spawn_received(
	shot_id: int,
	firing_peer_id: int,
	shell_spec_path: String,
	spawn_position: Vector2,
	shell_velocity: Vector2,
	shell_rotation: float
)
signal arena_shell_impact_received(
	shot_id: int,
	firing_peer_id: int,
	target_peer_id: int,
	result_type: int,
	damage: int,
	remaining_health: int,
	hit_position: Vector2,
	post_impact_velocity: Vector2,
	post_impact_rotation: float,
	continue_simulation: bool
)

const MultiplayerProtocolData := preload("res://net/multiplayer_protocol.gd")
const NetworkClientConnectionUtilsData := preload("res://net/network_client_connection_utils.gd")
const RPC_CHANNEL_INPUT: int = 1
const RPC_CHANNEL_STATE: int = 2
const VERBOSE_JOIN_LOGS: bool = false

var client_peer: ENetMultiplayerPeer
var default_connect_host: String = "ironfront.vikng.dev"
var default_connect_port: int = 7000
var protocol_version: int = MultiplayerProtocolData.PROTOCOL_VERSION
var cancel_join_requested: bool = false
var join_attempt_id: int = 0
var assigned_spawn_position: Vector2 = Vector2.ZERO
var assigned_spawn_rotation: float = 0.0
var arena_input_enabled: bool = false
var input_send_interval_seconds: float = 1.0 / float(MultiplayerProtocolData.INPUT_SEND_RATE_HZ)
var input_send_elapsed_seconds: float = 0.0
var local_input_tick: int = 0
var local_fire_request_seq: int = 0
var pending_left_track_input: float = 0.0
var pending_right_track_input: float = 0.0
var pending_turret_aim: float = 0.0


func _ready() -> void:
	_setup_client_network_logging()
	_setup_gameplay_input_capture()


func _process(delta: float) -> void:
	if not _can_send_input_intents():
		return
	input_send_elapsed_seconds += delta
	if input_send_elapsed_seconds < input_send_interval_seconds:
		return
	input_send_elapsed_seconds = 0.0
	local_input_tick += 1
	_receive_input_intent.rpc_id(
		1, local_input_tick, pending_left_track_input, pending_right_track_input, pending_turret_aim
	)


func connect_to_server() -> void:
	join_attempt_id += 1
	cancel_join_requested = false
	_log_join("connect_requested")
	if multiplayer.multiplayer_peer != null:
		if multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
			multiplayer.multiplayer_peer = null
			_log_join("cleared_offline_multiplayer_peer")
		else:
			var connection_status: MultiplayerPeer.ConnectionStatus = (
				multiplayer.multiplayer_peer.get_connection_status()
			)
			_log_join("existing_peer_status=%d" % connection_status)
			if connection_status == MultiplayerPeer.CONNECTION_CONNECTED:
				_log_join("already_connected -> request_join_arena")
				join_status_changed.emit("CONNECTED. REQUESTING ARENA JOIN...", false)
				_send_join_arena()
				return
			if connection_status == MultiplayerPeer.CONNECTION_CONNECTING:
				_log_join("connect_ignored_connection_in_progress")
				join_status_changed.emit("CONNECTING TO ONLINE SERVER...", false)
				return
			multiplayer.multiplayer_peer = null
			_log_join("cleared_stale_multiplayer_peer")

	if client_peer != null:
		client_peer.close()
		client_peer = null

	var host: String = default_connect_host
	var port: int = default_connect_port

	client_peer = ENetMultiplayerPeer.new()
	var create_error: int = client_peer.create_client(host, port)
	if create_error != OK:
		_log_join("create_client_failed host=%s port=%d error=%d" % [host, port, create_error])
		push_error(
			"%s failed create_client %s:%d error=%d" % [_log_prefix(), host, port, create_error]
		)
		return

	multiplayer.multiplayer_peer = client_peer
	_log_join("connecting_to=udp://%s:%d" % [host, port])
	join_status_changed.emit("CONNECTING TO ONLINE SERVER...", false)


func _setup_client_network_logging() -> void:
	Utils.connect_checked(multiplayer.connected_to_server, _on_connected_to_server)
	Utils.connect_checked(multiplayer.connection_failed, _on_connection_failed)
	Utils.connect_checked(multiplayer.server_disconnected, _on_server_disconnected)


func _setup_gameplay_input_capture() -> void:
	Utils.connect_checked(GameplayBus.lever_input, _on_lever_input)
	Utils.connect_checked(GameplayBus.wheel_input, _on_wheel_input)
	Utils.connect_checked(GameplayBus.fire_input, _on_fire_input)


func _on_connected_to_server() -> void:
	_log_join("connected_to_server unique_peer_id=%d" % multiplayer.get_unique_id())
	join_status_changed.emit("CONNECTED. NEGOTIATING SESSION...", false)
	_send_client_hello()


func _on_connection_failed() -> void:
	if cancel_join_requested:
		_log_join("connection_failed_ignored_due_to_cancel")
		cancel_join_requested = false
		return
	_log_join("connection_failed")
	push_warning("%s connection_failed" % _log_prefix())
	join_status_changed.emit("ONLINE JOIN FAILED: CONNECTION FAILED", true)
	join_arena_completed.emit(false, "CONNECTION FAILED")
	_reset_connection()


func _on_server_disconnected() -> void:
	if cancel_join_requested:
		_log_join("server_disconnected_ignored_due_to_cancel")
		cancel_join_requested = false
		return
	_log_join("server_disconnected")
	push_warning("%s server_disconnected" % _log_prefix())
	join_status_changed.emit("ONLINE JOIN FAILED: SERVER DISCONNECTED", true)
	join_arena_completed.emit(false, "SERVER DISCONNECTED")
	_reset_connection()


func _send_client_hello() -> void:
	if multiplayer.multiplayer_peer == null:
		_log_join("skip_send_client_hello no_multiplayer_peer")
		return
	var player_data: PlayerData = PlayerData.get_instance()
	var player_name: String = player_data.player_name
	_receive_client_hello.rpc_id(1, protocol_version, player_name)
	_log_join("sent_client_hello protocol=%d player=%s" % [protocol_version, player_name])


func _send_join_arena() -> void:
	if multiplayer.multiplayer_peer == null:
		_log_join("skip_send_join_arena no_multiplayer_peer")
		return
	var player_data: PlayerData = PlayerData.get_instance()
	var player_name: String = player_data.player_name
	_join_arena.rpc_id(1, player_name)
	_log_join("sent_join_arena player=%s" % player_name)


func cancel_join_request() -> void:
	if multiplayer.multiplayer_peer == null and client_peer == null:
		_log_join("cancel_ignored_no_active_connection")
		return
	cancel_join_requested = true
	_log_join("cancel_requested_resetting_connection")
	_reset_connection()
	join_arena_completed.emit(false, "CANCELED")


func set_arena_input_enabled(enabled: bool) -> void:
	arena_input_enabled = enabled
	if not arena_input_enabled:
		pending_left_track_input = 0.0
		pending_right_track_input = 0.0
		pending_turret_aim = 0.0
		input_send_elapsed_seconds = 0.0
		local_input_tick = 0
		local_fire_request_seq = 0


func _reset_connection() -> void:
	_log_join("reset_connection begin")
	if client_peer != null:
		client_peer.close()
		client_peer = null
	multiplayer.multiplayer_peer = null
	assigned_spawn_position = Vector2.ZERO
	assigned_spawn_rotation = 0.0
	set_arena_input_enabled(false)
	_log_join("reset_connection complete")


@rpc("authority", "reliable")
func _receive_server_hello_ack(server_protocol_version: int, server_unix_time: int) -> void:
	_log_join(
		(
			"received_server_hello_ack protocol=%d server_time=%d"
			% [server_protocol_version, server_unix_time]
		)
	)
	if server_protocol_version != protocol_version:
		_log_join(
			(
				"server_hello_ack_protocol_mismatch client=%d server=%d"
				% [protocol_version, server_protocol_version]
			)
		)
		join_status_changed.emit("ONLINE JOIN FAILED: PROTOCOL MISMATCH", true)
		join_arena_completed.emit(false, "PROTOCOL MISMATCH")
		_reset_connection()
		return
	join_status_changed.emit("CONNECTED. REQUESTING ARENA JOIN...", false)
	_send_join_arena()


@rpc("any_peer", "reliable")
func _receive_client_hello(client_protocol_version: int, player_name: String) -> void:
	push_warning(
		(
			"[client] unexpected RPC: _receive_client_hello protocol=%d player=%s"
			% [client_protocol_version, player_name]
		)
	)


@rpc("any_peer", "reliable")
func _join_arena(player_name: String) -> void:
	push_warning("[client] unexpected RPC: _join_arena player=%s" % player_name)


@rpc("authority", "reliable")
func _receive_state_snapshot(server_tick: int, player_states: Array) -> void:
	state_snapshot_received.emit(server_tick, player_states)


@rpc("any_peer", "call_remote", "unreliable_ordered", RPC_CHANNEL_INPUT)
func _receive_input_intent(
	input_tick: int, left_track_input: float, right_track_input: float, turret_aim: float
) -> void:
	push_warning(
		(
			(
				"[client] unexpected RPC: _receive_input_intent tick=%d left=%.4f "
				+ "right=%.4f turret=%.4f"
			)
			% [input_tick, left_track_input, right_track_input, turret_aim]
		)
	)


@rpc("any_peer", "reliable")
func _request_fire(fire_request_seq: int) -> void:
	push_warning("[client] unexpected RPC: _request_fire seq=%d" % fire_request_seq)


@rpc("authority", "reliable")
func _join_arena_ack(
	success: bool, message: String, spawn_position: Vector2, spawn_rotation: float
) -> void:
	if cancel_join_requested:
		_log_join(
			(
				(
					"join_arena_ack_ignored_due_to_cancel success=%s message=%s "
					+ "spawn_position=%s spawn_rotation=%.4f"
				)
				% [success, message, spawn_position, spawn_rotation]
			)
		)
		cancel_join_requested = false
		return
	var log_message: String = (
		("%s join_arena_ack success=%s message=%s " + "spawn_position=%s spawn_rotation=%.4f")
		% [_log_prefix(), success, message, spawn_position, spawn_rotation]
	)
	_log_join("received_%s" % log_message)
	if success:
		assigned_spawn_position = spawn_position
		assigned_spawn_rotation = spawn_rotation
		print(log_message)
		join_status_changed.emit("ONLINE JOIN SUCCESS: %s" % message, false)
	else:
		push_warning(log_message)
		join_status_changed.emit("ONLINE JOIN FAILED: %s" % message, true)
		_reset_connection()
	join_arena_completed.emit(success, message)


@rpc("authority", "reliable")
func _receive_arena_shell_spawn(
	shot_id: int,
	firing_peer_id: int,
	shell_spec_path: String,
	spawn_position: Vector2,
	shell_velocity: Vector2,
	shell_rotation: float
) -> void:
	arena_shell_spawn_received.emit(
		shot_id, firing_peer_id, shell_spec_path, spawn_position, shell_velocity, shell_rotation
	)


@rpc("authority", "reliable")
func _receive_arena_shell_impact(
	shot_id: int,
	firing_peer_id: int,
	target_peer_id: int,
	result_type: int,
	damage: int,
	remaining_health: int,
	hit_position: Vector2,
	post_impact_velocity: Vector2,
	post_impact_rotation: float,
	continue_simulation: bool
) -> void:
	arena_shell_impact_received.emit(
		shot_id,
		firing_peer_id,
		target_peer_id,
		result_type,
		damage,
		remaining_health,
		hit_position,
		post_impact_velocity,
		post_impact_rotation,
		continue_simulation
	)


func _on_lever_input(lever_side: Lever.LeverSide, value: float) -> void:
	if lever_side == Lever.LeverSide.LEFT:
		pending_left_track_input = clamp(value, -1.0, 1.0)
	elif lever_side == Lever.LeverSide.RIGHT:
		pending_right_track_input = clamp(value, -1.0, 1.0)


func _on_wheel_input(value: float) -> void:
	pending_turret_aim = clamp(value, -1.0, 1.0)


func _on_fire_input() -> void:
	if not _can_send_input_intents():
		return
	local_fire_request_seq += 1
	_request_fire.rpc_id(1, local_fire_request_seq)


func _log_join(message: String) -> void:
	if not VERBOSE_JOIN_LOGS:
		return
	print("%s[join:%d] %s" % [_log_prefix(), join_attempt_id, message])


func _log_prefix() -> String:
	return "[client pid=%d peer=%d]" % [OS.get_process_id(), _get_safe_peer_id()]


func _get_safe_peer_id() -> int:
	return NetworkClientConnectionUtilsData.get_safe_peer_id(multiplayer)


func _can_send_input_intents() -> bool:
	return NetworkClientConnectionUtilsData.can_send_input_intents(multiplayer, arena_input_enabled)


func should_show_ping_indicator() -> bool:
	return _can_send_input_intents()


func get_connection_ping_msec() -> int:
	return NetworkClientConnectionUtilsData.get_connection_ping_msec(
		multiplayer, arena_input_enabled
	)
