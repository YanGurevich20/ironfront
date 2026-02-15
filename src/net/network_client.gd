class_name NetworkClient
extends Node

signal join_status_changed(message: String, is_error: bool)
signal join_arena_completed(success: bool, message: String)
signal state_snapshot_received(server_tick: int, player_states: Array, max_players: int)
signal arena_shell_spawn_received
signal arena_shell_impact_received
signal arena_respawn_received(
	peer_id: int, player_name: String, spawn_position: Vector2, spawn_rotation: float
)
signal arena_fire_rejected_received(reason: String)
signal arena_loadout_state_received(
	selected_shell_path: String, shell_counts_by_path: Dictionary, reload_time_left: float
)

const MultiplayerProtocolData := preload("res://src/net/multiplayer_protocol.gd")
const NetworkClientConnectionUtilsData := preload(
	"res://src/net/network_client_connection_utils.gd"
)
const NetworkClientInputCaptureUtilsData := preload(
	"res://src/net/network_client_input_capture_utils.gd"
)
const NetworkClientJoinPayloadUtilsData := preload(
	"res://src/net/network_client_join_payload_utils.gd"
)
const NetworkClientJoinAckUtilsData := preload("res://src/net/network_client_join_ack_utils.gd")
const NetworkClientKillFeedUtilsData := preload("res://src/net/network_client_kill_feed_utils.gd")
const RPC_CHANNEL_INPUT: int = 1
const VERBOSE_JOIN_LOGS: bool = false

var client_peer: ENetMultiplayerPeer
var default_connect_host: String = "ironfront.vikng.dev"
var default_connect_port: int = 7000
var protocol_version: int = MultiplayerProtocolData.PROTOCOL_VERSION
var cancel_join_requested: bool = false
var join_attempt_id: int = 0
var assigned_spawn_position: Vector2 = Vector2.ZERO
var assigned_spawn_rotation: float = 0.0
var arena_membership_active: bool = false
var arena_input_enabled: bool = false
var input_send_interval_seconds: float = 1.0 / float(MultiplayerProtocolData.INPUT_SEND_RATE_HZ)
var input_send_elapsed_seconds: float = 0.0
var local_input_tick: int = 0
var local_fire_request_seq: int = 0
var local_shell_select_seq: int = 0
var pending_left_track_input: float = 0.0
var pending_right_track_input: float = 0.0
var pending_turret_aim: float = 0.0


func _ready() -> void:
	var resolved_target: Dictionary = NetworkClientConnectionUtilsData.resolve_cli_connect_target(
		default_connect_host, default_connect_port
	)
	default_connect_host = resolved_target.get("host", default_connect_host)
	default_connect_port = resolved_target.get("port", default_connect_port)
	Utils.connect_checked(multiplayer.connected_to_server, _on_connected_to_server)
	Utils.connect_checked(multiplayer.connection_failed, _on_connection_failed)
	Utils.connect_checked(multiplayer.server_disconnected, _on_server_disconnected)
	NetworkClientInputCaptureUtilsData.setup_for_client(self)


func _process(delta: float) -> void:
	if not NetworkClientConnectionUtilsData.can_send_input_intents(
		multiplayer, arena_input_enabled
	):
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
		push_error("[client] failed create_client %s:%d error=%d" % [host, port, create_error])
		return

	multiplayer.multiplayer_peer = client_peer
	_log_join("connecting_to=udp://%s:%d" % [host, port])
	join_status_changed.emit("CONNECTING TO ONLINE SERVER...", false)


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
	push_warning("[client] connection_failed")
	join_status_changed.emit("ONLINE JOIN FAILED: CONNECTION FAILED", true)
	join_arena_completed.emit(false, "CONNECTION FAILED")
	_reset_connection()


func _on_server_disconnected() -> void:
	if cancel_join_requested:
		_log_join("server_disconnected_ignored_due_to_cancel")
		cancel_join_requested = false
		return
	_log_join("server_disconnected")
	push_warning("[client] server_disconnected")
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
	var join_loadout_payload: Dictionary = (
		NetworkClientJoinPayloadUtilsData.build_join_loadout_payload(player_data)
	)
	var selected_tank_id: int = int(
		join_loadout_payload.get("tank_id", ArenaSessionState.DEFAULT_TANK_ID)
	)
	var shell_loadout_by_path: Dictionary = join_loadout_payload.get("shell_loadout_by_path", {})
	var selected_shell_path: String = str(join_loadout_payload.get("selected_shell_path", ""))
	_join_arena.rpc_id(1, player_name, selected_tank_id, shell_loadout_by_path, selected_shell_path)
	_log_join("sent_join_arena player=%s tank=%d" % [player_name, selected_tank_id])


func cancel_join_request() -> void:
	if multiplayer.multiplayer_peer == null and client_peer == null:
		_log_join("cancel_ignored_no_active_connection")
		return
	cancel_join_requested = true
	_log_join("cancel_requested_resetting_connection")
	_reset_connection()
	join_arena_completed.emit(false, "CANCELED")


func leave_arena() -> void:
	if not arena_membership_active:
		return
	arena_membership_active = false
	assigned_spawn_position = Vector2.ZERO
	assigned_spawn_rotation = 0.0
	set_arena_input_enabled(false)
	if not NetworkClientConnectionUtilsData.is_connected_to_server(multiplayer):
		return
	_leave_arena.rpc_id(1)
	_log_join("sent_leave_arena")


func request_arena_respawn() -> void:
	if not arena_membership_active:
		return
	if not NetworkClientConnectionUtilsData.is_connected_to_server(multiplayer):
		return
	_request_respawn.rpc_id(1)


func set_arena_input_enabled(enabled: bool, reset_sequence_state: bool = true) -> void:
	arena_input_enabled = enabled
	if not arena_input_enabled:
		pending_left_track_input = 0.0
		pending_right_track_input = 0.0
		pending_turret_aim = 0.0
		input_send_elapsed_seconds = 0.0
		if reset_sequence_state:
			local_input_tick = 0
			local_fire_request_seq = 0
			local_shell_select_seq = 0


func _reset_connection() -> void:
	_log_join("reset_connection begin")
	if client_peer != null:
		client_peer.close()
		client_peer = null
	multiplayer.multiplayer_peer = null
	assigned_spawn_position = Vector2.ZERO
	assigned_spawn_rotation = 0.0
	arena_membership_active = false
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
func _receive_client_hello(_client_protocol_version: int, _player_name: String) -> void:
	push_warning("[client] unexpected RPC: _receive_client_hello")


@rpc("any_peer", "reliable")
func _join_arena(
	_player_name: String,
	_requested_tank_id: int,
	_requested_shell_loadout_by_path: Dictionary,
	_requested_selected_shell_path: String
) -> void:
	push_warning("[client] unexpected RPC: _join_arena")


@rpc("any_peer", "reliable")
func _leave_arena() -> void:
	push_warning("[client] unexpected RPC: _leave_arena")


@rpc("authority", "reliable")
func _receive_state_snapshot(server_tick: int, player_states: Array, max_players: int) -> void:
	state_snapshot_received.emit(server_tick, player_states, max_players)


@rpc("any_peer", "call_remote", "unreliable_ordered", RPC_CHANNEL_INPUT)
func _receive_input_intent(
	_input_tick: int, _left_track_input: float, _right_track_input: float, _turret_aim: float
) -> void:
	push_warning("[client] unexpected RPC: _receive_input_intent")


@rpc("any_peer", "reliable")
func _request_fire(_fire_request_seq: int) -> void:
	push_warning("[client] unexpected RPC: _request_fire")


@rpc("any_peer", "reliable")
func _request_shell_select(_shell_select_seq: int, _shell_spec_path: String) -> void:
	push_warning("[client] unexpected RPC: _request_shell_select")


@rpc("any_peer", "reliable")
func _request_respawn() -> void:
	push_warning("[client] unexpected RPC: _request_respawn")


@rpc("authority", "reliable")
func _join_arena_ack(
	success: bool, message: String, spawn_position: Vector2, spawn_rotation: float
) -> void:
	NetworkClientJoinAckUtilsData.handle_join_arena_ack(
		self, success, message, spawn_position, spawn_rotation
	)


@rpc("authority", "reliable")
func _leave_arena_ack(success: bool, message: String) -> void:
	_log_join("received_leave_arena_ack success=%s message=%s" % [success, message])


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


@rpc("authority", "reliable")
func _receive_arena_respawn(
	peer_id: int, player_name: String, spawn_position: Vector2, spawn_rotation: float
) -> void:
	arena_respawn_received.emit(peer_id, player_name, spawn_position, spawn_rotation)


@rpc("authority", "reliable")
func _receive_arena_fire_rejected(reason: String) -> void:
	arena_fire_rejected_received.emit(reason)


@rpc("authority", "reliable")
func _receive_arena_loadout_state(
	selected_shell_path: String, shell_counts_by_path: Dictionary, reload_time_left: float
) -> void:
	arena_loadout_state_received.emit(selected_shell_path, shell_counts_by_path, reload_time_left)


@rpc("authority", "reliable")
func _receive_arena_kill_event(kill_event_payload: Dictionary) -> void:
	NetworkClientKillFeedUtilsData.handle_kill_event_payload(kill_event_payload)


func _log_join(message: String) -> void:
	if not VERBOSE_JOIN_LOGS:
		return
	print("[client][join:%d] %s" % [join_attempt_id, message])


func get_connection_ping_msec() -> int:
	return NetworkClientConnectionUtilsData.get_connection_ping_msec(
		multiplayer, arena_input_enabled
	)
