class_name ClientOnlineRuntime
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

const VERBOSE_JOIN_LOGS: bool = false

var default_connect_host: String = "ironfront.vikng.dev"
var default_connect_port: int = 7000
var protocol_version: int = MultiplayerProtocol.PROTOCOL_VERSION
var cancel_join_requested: bool = false
var join_attempt_id: int = 0
var assigned_spawn_position: Vector2 = Vector2.ZERO
var assigned_spawn_rotation: float = 0.0
var arena_membership_active: bool = false
var arena_input_enabled: bool = false
var input_send_interval_seconds: float = 1.0 / float(MultiplayerProtocol.INPUT_SEND_RATE_HZ)
var input_send_elapsed_seconds: float = 0.0
var local_input_tick: int = 0
var local_fire_request_seq: int = 0
var local_shell_select_seq: int = 0
var pending_left_track_input: float = 0.0
var pending_right_track_input: float = 0.0
var pending_turret_aim: float = 0.0

@onready var enet_client: ENetClient = %Network
@onready var session_api: ClientSessionApi = %Session
@onready var gameplay_api: ClientGameplayApi = %Gameplay


func _ready() -> void:
	Utils.connect_checked(multiplayer.connected_to_server, _on_connected_to_server)
	Utils.connect_checked(multiplayer.connection_failed, _on_connection_failed)
	Utils.connect_checked(multiplayer.server_disconnected, _on_server_disconnected)
	Utils.connect_checked(session_api.server_hello_ack_received, _on_server_hello_ack_received)
	Utils.connect_checked(session_api.join_arena_ack_received, _on_join_arena_ack_received)
	Utils.connect_checked(session_api.leave_arena_ack_received, _on_leave_arena_ack_received)
	Utils.connect_checked(gameplay_api.state_snapshot_received, _on_state_snapshot_received)
	Utils.connect_checked(gameplay_api.arena_shell_spawn_received, _on_arena_shell_spawn_received)
	Utils.connect_checked(gameplay_api.arena_shell_impact_received, _on_arena_shell_impact_received)
	Utils.connect_checked(gameplay_api.arena_respawn_received, _on_arena_respawn_received)
	Utils.connect_checked(
		gameplay_api.arena_fire_rejected_received, _on_arena_fire_rejected_received
	)
	Utils.connect_checked(
		gameplay_api.arena_loadout_state_received, _on_arena_loadout_state_received
	)
	Utils.connect_checked(gameplay_api.arena_kill_event_received, _on_arena_kill_event_received)
	Utils.connect_checked(GameplayBus.lever_input, _on_lever_input)
	Utils.connect_checked(GameplayBus.wheel_input, _on_wheel_input)
	Utils.connect_checked(GameplayBus.fire_input, request_fire)
	Utils.connect_checked(GameplayBus.shell_selected, _on_shell_selected)


func _process(delta: float) -> void:
	if not _can_send_gameplay_requests():
		return
	input_send_elapsed_seconds += delta
	if input_send_elapsed_seconds < input_send_interval_seconds:
		return
	input_send_elapsed_seconds = 0.0
	local_input_tick += 1
	gameplay_api.send_input_intent(
		local_input_tick, pending_left_track_input, pending_right_track_input, pending_turret_aim
	)


func connect_to_server() -> void:
	join_attempt_id += 1
	cancel_join_requested = false
	_log_join("connect_requested")
	if multiplayer.multiplayer_peer != null:
		if multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
			enet_client.reset_connection()
			_log_join("cleared_offline_multiplayer_peer")
		else:
			var connection_status: MultiplayerPeer.ConnectionStatus = (
				multiplayer.multiplayer_peer.get_connection_status()
			)
			_log_join("existing_peer_status=%d" % connection_status)
			if connection_status == MultiplayerPeer.CONNECTION_CONNECTED:
				join_status_changed.emit("CONNECTED. REQUESTING ARENA JOIN...", false)
				_send_join_arena()
				return
			if connection_status == MultiplayerPeer.CONNECTION_CONNECTING:
				join_status_changed.emit("CONNECTING TO ONLINE SERVER...", false)
				return
			enet_client.reset_connection()
			_log_join("cleared_stale_multiplayer_peer")
	var resolved_target: Dictionary = NetworkClientConnectionUtils.resolve_cli_connect_target(
		default_connect_host, default_connect_port
	)
	var host: String = resolved_target.get("host", default_connect_host)
	var port: int = resolved_target.get("port", default_connect_port)
	if not enet_client.connect_to_server(host, port):
		_emit_join_failed("CONNECTION FAILED")
		return
	_log_join("connecting_to=udp://%s:%d" % [host, port])
	join_status_changed.emit("CONNECTING TO ONLINE SERVER...", false)


func cancel_join_request() -> void:
	if multiplayer.multiplayer_peer == null:
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
	if not enet_client.is_connected_to_server():
		return
	session_api.send_leave_arena()
	_log_join("sent_leave_arena")


func request_arena_respawn() -> void:
	if not arena_membership_active:
		return
	if not enet_client.is_connected_to_server():
		return
	gameplay_api.request_respawn()


func request_fire() -> void:
	if not _can_send_gameplay_requests():
		return
	local_fire_request_seq += 1
	gameplay_api.request_fire(local_fire_request_seq)


func request_shell_select(shell_spec_path: String) -> void:
	if shell_spec_path.is_empty():
		return
	if not _can_send_gameplay_requests():
		return
	local_shell_select_seq += 1
	gameplay_api.request_shell_select(local_shell_select_seq, shell_spec_path)


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
	_emit_join_failed("CONNECTION FAILED")
	_reset_connection()


func _on_server_disconnected() -> void:
	if cancel_join_requested:
		_log_join("server_disconnected_ignored_due_to_cancel")
		cancel_join_requested = false
		return
	_log_join("server_disconnected")
	push_warning("[client] server_disconnected")
	_emit_join_failed("SERVER DISCONNECTED")
	_reset_connection()


func _send_client_hello() -> void:
	if multiplayer.multiplayer_peer == null:
		_log_join("skip_send_client_hello no_multiplayer_peer")
		return
	var player_data: PlayerData = PlayerData.get_instance()
	var player_name: String = player_data.player_name
	session_api.send_client_hello(protocol_version, player_name)
	_log_join("sent_client_hello protocol=%d player=%s" % [protocol_version, player_name])


func _send_join_arena() -> void:
	if multiplayer.multiplayer_peer == null:
		_log_join("skip_send_join_arena no_multiplayer_peer")
		return
	var player_data: PlayerData = PlayerData.get_instance()
	var player_name: String = player_data.player_name
	var join_loadout_payload: Dictionary = NetworkClientJoinPayloadUtils.build_join_loadout_payload(
		player_data
	)
	var selected_tank_id: int = int(
		join_loadout_payload.get("tank_id", ArenaSessionState.DEFAULT_TANK_ID)
	)
	var shell_loadout_by_path: Dictionary = join_loadout_payload.get("shell_loadout_by_path", {})
	var selected_shell_path: String = str(join_loadout_payload.get("selected_shell_path", ""))
	session_api.send_join_arena(
		player_name, selected_tank_id, shell_loadout_by_path, selected_shell_path
	)
	_log_join("sent_join_arena player=%s tank=%d" % [player_name, selected_tank_id])


func _on_server_hello_ack_received(server_protocol_version: int, server_unix_time: int) -> void:
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
		_emit_join_failed("PROTOCOL MISMATCH")
		_reset_connection()
		return
	join_status_changed.emit("CONNECTED. REQUESTING ARENA JOIN...", false)
	_send_join_arena()


func _on_join_arena_ack_received(
	success: bool, message: String, spawn_position: Vector2, spawn_rotation: float
) -> void:
	if cancel_join_requested:
		_log_join("join_arena_ack_ignored_due_to_cancel")
		cancel_join_requested = false
		return
	_log_join("join_arena_ack success=%s message=%s" % [success, message])
	if success:
		assigned_spawn_position = spawn_position
		assigned_spawn_rotation = spawn_rotation
		arena_membership_active = true
		join_status_changed.emit("ONLINE JOIN SUCCESS: %s" % message, false)
	else:
		arena_membership_active = false
		push_warning("[client] join_arena_ack_failed message=%s" % message)
		_emit_join_failed(message)
		_reset_connection()
		return
	join_arena_completed.emit(true, message)


func _on_leave_arena_ack_received(success: bool, message: String) -> void:
	_log_join("received_leave_arena_ack success=%s message=%s" % [success, message])


func _on_state_snapshot_received(server_tick: int, player_states: Array, max_players: int) -> void:
	state_snapshot_received.emit(server_tick, player_states, max_players)


func _on_arena_shell_spawn_received(
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


func _on_arena_shell_impact_received(
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


func _on_arena_respawn_received(
	peer_id: int, player_name: String, spawn_position: Vector2, spawn_rotation: float
) -> void:
	arena_respawn_received.emit(peer_id, player_name, spawn_position, spawn_rotation)


func _on_arena_fire_rejected_received(reason: String) -> void:
	arena_fire_rejected_received.emit(reason)


func _on_arena_loadout_state_received(
	selected_shell_path: String, shell_counts_by_path: Dictionary, reload_time_left: float
) -> void:
	arena_loadout_state_received.emit(selected_shell_path, shell_counts_by_path, reload_time_left)


func _on_arena_kill_event_received(kill_event_payload: Dictionary) -> void:
	var event_seq: int = int(kill_event_payload.get("event_seq", 0))
	var killer_peer_id: int = int(kill_event_payload.get("killer_peer_id", 0))
	var killer_name: String = str(kill_event_payload.get("killer_name", ""))
	var killer_tank_name: String = str(kill_event_payload.get("killer_tank_name", ""))
	var shell_short_name: String = str(kill_event_payload.get("shell_short_name", ""))
	var victim_peer_id: int = int(kill_event_payload.get("victim_peer_id", 0))
	var victim_name: String = str(kill_event_payload.get("victim_name", ""))
	var victim_tank_name: String = str(kill_event_payload.get("victim_tank_name", ""))
	GameplayBus.online_kill_feed_event.emit(
		event_seq,
		killer_peer_id,
		killer_name,
		killer_tank_name,
		shell_short_name,
		victim_peer_id,
		victim_name,
		victim_tank_name
	)


func _on_lever_input(lever_side: Lever.LeverSide, value: float) -> void:
	if lever_side == Lever.LeverSide.LEFT:
		pending_left_track_input = clamp(value, -1.0, 1.0)
	elif lever_side == Lever.LeverSide.RIGHT:
		pending_right_track_input = clamp(value, -1.0, 1.0)


func _on_wheel_input(value: float) -> void:
	pending_turret_aim = clamp(value, -1.0, 1.0)


func _on_shell_selected(shell_spec: ShellSpec, remaining_shell_count: int) -> void:
	if remaining_shell_count < 0:
		return
	if shell_spec == null:
		return
	request_shell_select(shell_spec.resource_path)


func _can_send_gameplay_requests() -> bool:
	return arena_input_enabled and enet_client.is_connected_to_server()


func _emit_join_failed(reason: String) -> void:
	join_status_changed.emit("ONLINE JOIN FAILED: %s" % reason, true)
	join_arena_completed.emit(false, reason)


func _reset_connection() -> void:
	_log_join("reset_connection begin")
	enet_client.reset_connection()
	assigned_spawn_position = Vector2.ZERO
	assigned_spawn_rotation = 0.0
	arena_membership_active = false
	set_arena_input_enabled(false)
	_log_join("reset_connection complete")


func _log_join(message: String) -> void:
	if not VERBOSE_JOIN_LOGS:
		return
	print("[client][join:%d] %s" % [join_attempt_id, message])
