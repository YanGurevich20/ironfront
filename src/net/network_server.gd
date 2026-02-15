class_name NetworkServer
extends Node

signal arena_peer_disconnected(peer_id: int)
signal arena_join_requested(
	peer_id: int,
	player_name: String,
	requested_tank_id: int,
	requested_shell_loadout_by_path: Dictionary,
	requested_selected_shell_path: String
)
signal arena_leave_requested(peer_id: int)
signal arena_input_intent_received(
	peer_id: int,
	input_tick: int,
	left_track_input: float,
	right_track_input: float,
	turret_aim: float
)
signal arena_fire_requested(peer_id: int, fire_request_seq: int)
signal arena_shell_select_requested(peer_id: int, shell_select_seq: int, shell_spec_path: String)
signal arena_respawn_requested(peer_id: int)

const RPC_CHANNEL_INPUT: int = 1

var server_peer: ENetMultiplayerPeer
var protocol_version: int = MultiplayerProtocol.PROTOCOL_VERSION
var arena_session_state: ArenaSessionState
var server_tick_rate_hz: int = 30
var snapshot_interval_ticks: int = 2
var total_on_server_tick_calls: int = 0
var total_on_server_tick_active_calls: int = 0
var total_snapshot_gate_hits: int = 0
var total_input_messages_received: int = 0
var total_input_messages_applied: int = 0
var total_fire_requests_received: int = 0
var total_fire_requests_applied: int = 0
var total_snapshots_broadcast: int = 0
var last_snapshot_tick: int = -1
var authoritative_player_states: Array[Dictionary] = []


func configure_arena_session(session_state: ArenaSessionState) -> void:
	arena_session_state = session_state


func configure_tick_rate(tick_rate_hz: int) -> void:
	server_tick_rate_hz = max(1, tick_rate_hz)
	snapshot_interval_ticks = max(
		1, int(round(float(server_tick_rate_hz) / float(MultiplayerProtocol.SNAPSHOT_RATE_HZ)))
	)
	print(
		(
			"[server][sync] configured tick_rate_hz=%d snapshot_interval_ticks=%d"
			% [server_tick_rate_hz, snapshot_interval_ticks]
		)
	)


func start_server(listen_port: int, max_clients: int) -> bool:
	server_peer = ENetMultiplayerPeer.new()
	var error_code: int = server_peer.create_server(listen_port, max_clients)
	if error_code != OK:
		push_error("Server failed to start on port %d (error %d)" % [listen_port, error_code])
		return false

	multiplayer.multiplayer_peer = server_peer
	Utils.connect_checked(multiplayer.peer_disconnected, _on_peer_disconnected)

	print("[server] listening on udp://0.0.0.0:%d max_clients=%d" % [listen_port, max_clients])
	return true


func _on_peer_disconnected(peer_id: int) -> void:
	print("[server] peer_disconnected id=%d peers=%d" % [peer_id, multiplayer.get_peers().size()])
	arena_peer_disconnected.emit(peer_id)


@rpc("authority", "reliable")
func _receive_server_hello_ack(_server_protocol_version: int, _server_unix_time: int) -> void:
	push_warning("[server] unexpected RPC: _receive_server_hello_ack")


@rpc("any_peer", "reliable")
func _receive_client_hello(client_protocol_version: int, player_name: String) -> void:
	var peer_id: int = multiplayer.get_remote_sender_id()
	print("[server][join] client_hello peer=%d protocol=%d" % [peer_id, client_protocol_version])
	print("[server] client_hello peer=%d player=%s" % [peer_id, player_name])
	_receive_server_hello_ack.rpc_id(peer_id, protocol_version, Time.get_unix_time_from_system())


@rpc("any_peer", "reliable")
func _join_arena(
	player_name: String,
	requested_tank_id: int,
	requested_shell_loadout_by_path: Dictionary,
	requested_selected_shell_path: String
) -> void:
	var peer_id: int = multiplayer.get_remote_sender_id()
	arena_join_requested.emit(
		peer_id,
		player_name,
		requested_tank_id,
		requested_shell_loadout_by_path,
		requested_selected_shell_path
	)


@rpc("any_peer", "reliable")
func _leave_arena() -> void:
	var peer_id: int = multiplayer.get_remote_sender_id()
	arena_leave_requested.emit(peer_id)


@rpc("authority", "reliable")
func _receive_state_snapshot(_server_tick: int, _player_states: Array, _max_players: int) -> void:
	push_warning("[server] unexpected RPC: _receive_state_snapshot")


func on_server_tick(server_tick: int, tick_delta_seconds: float) -> void:
	total_on_server_tick_calls += 1
	if tick_delta_seconds <= 0.0:
		return
	if arena_session_state.get_player_count() == 0:
		return
	total_on_server_tick_active_calls += 1
	if server_tick % snapshot_interval_ticks == 0:
		total_snapshot_gate_hits += 1
		_broadcast_state_snapshot(server_tick)


func set_authoritative_player_states(player_states: Array[Dictionary]) -> void:
	authoritative_player_states.clear()
	for player_state: Dictionary in player_states:
		authoritative_player_states.append(player_state.duplicate(true))


func _broadcast_state_snapshot(server_tick: int) -> void:
	var snapshot_player_states: Array[Dictionary] = (
		NetworkServerSnapshotBuilder
		. build_player_states_snapshot(arena_session_state, authoritative_player_states)
	)
	var arena_max_players: int = arena_session_state.max_players
	var connected_peers: PackedInt32Array = multiplayer.get_peers()
	total_snapshots_broadcast += 1
	last_snapshot_tick = server_tick
	for peer_id: int in connected_peers:
		_receive_state_snapshot.rpc_id(
			peer_id, server_tick, snapshot_player_states, arena_max_players
		)


@rpc("any_peer", "call_remote", "unreliable_ordered", RPC_CHANNEL_INPUT)
func _receive_input_intent(
	input_tick: int, left_track_input: float, right_track_input: float, turret_aim: float
) -> void:
	total_input_messages_received += 1
	var peer_id: int = multiplayer.get_remote_sender_id()
	arena_input_intent_received.emit(
		peer_id, input_tick, left_track_input, right_track_input, turret_aim
	)


@rpc("any_peer", "reliable")
func _request_fire(fire_request_seq: int) -> void:
	total_fire_requests_received += 1
	var peer_id: int = multiplayer.get_remote_sender_id()
	arena_fire_requested.emit(peer_id, fire_request_seq)


@rpc("any_peer", "reliable")
func _request_shell_select(shell_select_seq: int, shell_spec_path: String) -> void:
	var peer_id: int = multiplayer.get_remote_sender_id()
	arena_shell_select_requested.emit(peer_id, shell_select_seq, shell_spec_path)


@rpc("any_peer", "reliable")
func _request_respawn() -> void:
	var peer_id: int = multiplayer.get_remote_sender_id()
	arena_respawn_requested.emit(peer_id)


@rpc("authority", "reliable")
func _join_arena_ack(
	_success: bool, _message: String, _spawn_position: Vector2, _spawn_rotation: float
) -> void:
	push_warning("[server] unexpected RPC: _join_arena_ack")


@rpc("authority", "reliable")
func _leave_arena_ack(_success: bool, _message: String) -> void:
	push_warning("[server] unexpected RPC: _leave_arena_ack")


@rpc("authority", "reliable")
func _receive_arena_shell_spawn(
	_shot_id: int,
	_firing_peer_id: int,
	_shell_spec_path: String,
	_spawn_position: Vector2,
	_shell_velocity: Vector2,
	_shell_rotation: float
) -> void:
	push_warning("[server] unexpected RPC: _receive_arena_shell_spawn")


@rpc("authority", "reliable")
func _receive_arena_shell_impact(
	_shot_id: int,
	_firing_peer_id: int,
	_target_peer_id: int,
	_result_type: int,
	_damage: int,
	_remaining_health: int,
	_hit_position: Vector2,
	_post_impact_velocity: Vector2,
	_post_impact_rotation: float,
	_continue_simulation: bool
) -> void:
	push_warning("[server] unexpected RPC: _receive_arena_shell_impact")


@rpc("authority", "reliable")
func _receive_arena_respawn(
	_peer_id: int, _player_name: String, _spawn_position: Vector2, _spawn_rotation: float
) -> void:
	push_warning("[server] unexpected RPC: _receive_arena_respawn")


@rpc("authority", "reliable")
func _receive_arena_fire_rejected(_reason: String) -> void:
	push_warning("[server] unexpected RPC: _receive_arena_fire_rejected")


@rpc("authority", "reliable")
func _receive_arena_loadout_state(
	_selected_shell_path: String, _shell_counts_by_path: Dictionary, _reload_time_left: float
) -> void:
	push_warning("[server] unexpected RPC: _receive_arena_loadout_state")


@rpc("authority", "reliable")
func _receive_arena_kill_event(_kill_event_payload: Dictionary) -> void:
	push_warning("[server] unexpected RPC: _receive_arena_kill_event")


func broadcast_arena_respawn(
	peer_id: int, player_name: String, spawn_position: Vector2, spawn_rotation: float
) -> void:
	for connected_peer_id: int in multiplayer.get_peers():
		_receive_arena_respawn.rpc_id(
			connected_peer_id, peer_id, player_name, spawn_position, spawn_rotation
		)


func send_arena_fire_rejected(peer_id: int, reason: String) -> void:
	if not multiplayer.get_peers().has(peer_id):
		return
	_receive_arena_fire_rejected.rpc_id(peer_id, reason)


func send_arena_loadout_state(
	peer_id: int,
	selected_shell_path: String,
	shell_counts_by_path: Dictionary,
	reload_time_left: float
) -> void:
	if not multiplayer.get_peers().has(peer_id):
		return
	_receive_arena_loadout_state.rpc_id(
		peer_id, selected_shell_path, shell_counts_by_path, reload_time_left
	)


func complete_arena_join(
	peer_id: int, join_message: String, spawn_position: Vector2, spawn_rotation: float
) -> void:
	_join_arena_ack.rpc_id(peer_id, true, join_message, spawn_position, spawn_rotation)
	_broadcast_state_snapshot(0)


func reject_arena_join(peer_id: int, join_message: String) -> void:
	_join_arena_ack.rpc_id(peer_id, false, join_message, Vector2.ZERO, 0.0)


func complete_arena_leave(peer_id: int, leave_message: String) -> void:
	_leave_arena_ack.rpc_id(peer_id, true, leave_message)


func mark_input_applied() -> void:
	total_input_messages_applied += 1


func mark_fire_request_applied() -> void:
	total_fire_requests_applied += 1


func broadcast_state_snapshot_now() -> void:
	_broadcast_state_snapshot(0)
