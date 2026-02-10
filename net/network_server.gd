class_name NetworkServer
extends Node

const MultiplayerProtocolData := preload("res://net/multiplayer_protocol.gd")
const RPC_CHANNEL_INPUT: int = 1
const RPC_CHANNEL_STATE: int = 2

var server_peer: ENetMultiplayerPeer
var protocol_version: int = MultiplayerProtocolData.PROTOCOL_VERSION
var arena_session_state: ArenaSessionState
var arena_spawn_transforms_by_id: Dictionary = {}
var occupied_spawn_peer_by_id: Dictionary = {}
var server_tick_rate_hz: int = 30
var snapshot_interval_ticks: int = 2
var total_on_server_tick_calls: int = 0
var total_on_server_tick_active_calls: int = 0
var total_snapshot_gate_hits: int = 0
var total_input_messages_received: int = 0
var total_input_messages_applied: int = 0
var total_snapshots_broadcast: int = 0
var last_snapshot_tick: int = -1


func configure_arena_session(session_state: ArenaSessionState) -> void:
	arena_session_state = session_state


func configure_arena_spawn_pool(spawn_transforms_by_id: Dictionary) -> void:
	arena_spawn_transforms_by_id = spawn_transforms_by_id.duplicate(true)
	occupied_spawn_peer_by_id.clear()
	print("[server][arena] configured_spawn_pool count=%d" % arena_spawn_transforms_by_id.size())


func configure_tick_rate(tick_rate_hz: int) -> void:
	server_tick_rate_hz = max(1, tick_rate_hz)
	snapshot_interval_ticks = max(
		1, int(round(float(server_tick_rate_hz) / float(MultiplayerProtocolData.SNAPSHOT_RATE_HZ)))
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
	Utils.connect_checked(multiplayer.peer_connected, _on_peer_connected)
	Utils.connect_checked(multiplayer.peer_disconnected, _on_peer_disconnected)
	Utils.connect_checked(multiplayer.connected_to_server, _on_connected_to_server)
	Utils.connect_checked(multiplayer.connection_failed, _on_connection_failed)
	Utils.connect_checked(multiplayer.server_disconnected, _on_server_disconnected)

	print("[server] listening on udp://0.0.0.0:%d max_clients=%d" % [listen_port, max_clients])
	return true


func _on_peer_connected(peer_id: int) -> void:
	print("[server] peer_connected id=%d peers=%d" % [peer_id, multiplayer.get_peers().size()])


func _on_peer_disconnected(peer_id: int) -> void:
	print("[server] peer_disconnected id=%d peers=%d" % [peer_id, multiplayer.get_peers().size()])
	if arena_session_state == null:
		push_warning("[server][arena] missing session state during disconnect")
		return
	var remove_result: Dictionary = arena_session_state.remove_peer(peer_id, "PEER_DISCONNECTED")
	if bool(remove_result.get("removed", false)):
		var released_spawn_id: StringName = remove_result.get("spawn_id", StringName())
		if released_spawn_id != StringName():
			_release_spawn_id(released_spawn_id, peer_id)
		print("[server][arena] peer_disconnected_cleanup peer=%d" % peer_id)


func _on_connected_to_server() -> void:
	push_warning("connected_to_server signal fired in server process")


func _on_connection_failed() -> void:
	push_warning("connection_failed signal fired in server process")


func _on_server_disconnected() -> void:
	push_warning("server_disconnected signal fired in server process")


@rpc("any_peer", "reliable")
func _receive_client_hello(client_protocol_version: int, player_name: String) -> void:
	if not multiplayer.is_server():
		return
	var peer_id: int = multiplayer.get_remote_sender_id()
	print(
		(
			"[server][join] receive_client_hello peer=%d server_protocol=%d client_protocol=%d"
			% [peer_id, protocol_version, client_protocol_version]
		)
	)
	print(
		(
			"[server] client_hello peer=%d protocol=%d player=%s"
			% [peer_id, client_protocol_version, player_name]
		)
	)
	_receive_server_hello_ack.rpc_id(peer_id, protocol_version, Time.get_unix_time_from_system())


@rpc("any_peer", "reliable")
func _join_arena(player_name: String) -> void:
	if not multiplayer.is_server():
		return
	if arena_session_state == null:
		push_error("[server][arena] join requested before session initialization")
		var missing_session_peer_id: int = multiplayer.get_remote_sender_id()
		_join_arena_ack.rpc_id(
			missing_session_peer_id, false, "ARENA SESSION UNAVAILABLE", Vector2.ZERO, 0.0
		)
		return
	if arena_spawn_transforms_by_id.is_empty():
		push_error("[server][arena] join requested with empty spawn pool")
		var missing_spawn_peer_id: int = multiplayer.get_remote_sender_id()
		_join_arena_ack.rpc_id(
			missing_spawn_peer_id, false, "ARENA SPAWNS UNAVAILABLE", Vector2.ZERO, 0.0
		)
		return
	var peer_id: int = multiplayer.get_remote_sender_id()
	var cleaned_player_name: String = player_name.strip_edges()
	print(
		(
			"[server][join] receive_join_arena peer=%d raw_player=%s cleaned_player=%s"
			% [peer_id, player_name, cleaned_player_name]
		)
	)
	if cleaned_player_name.is_empty():
		print("[server][join] reject_join_arena peer=%d reason=INVALID_PLAYER_NAME" % peer_id)
		_join_arena_ack.rpc_id(peer_id, false, "INVALID PLAYER NAME", Vector2.ZERO, 0.0)
		return
	var join_result: Dictionary = arena_session_state.try_join_peer(peer_id, cleaned_player_name)
	var join_success: bool = bool(join_result.get("success", false))
	var join_message: String = str(join_result.get("message", "JOIN FAILED"))
	if join_success:
		var assigned_spawn_id: StringName = _assign_random_available_spawn_id(peer_id)
		if assigned_spawn_id == StringName():
			print("[server][join] reject_join_arena peer=%d reason=NO_SPAWN_AVAILABLE" % peer_id)
			arena_session_state.remove_peer(peer_id, "NO_SPAWN_AVAILABLE")
			_join_arena_ack.rpc_id(peer_id, false, "NO SPAWN AVAILABLE", Vector2.ZERO, 0.0)
			return
		arena_session_state.set_peer_spawn_id(peer_id, assigned_spawn_id)
		var assigned_spawn_transform: Transform2D = arena_spawn_transforms_by_id[assigned_spawn_id]
		var assigned_spawn_position: Vector2 = assigned_spawn_transform.origin
		var assigned_spawn_rotation: float = assigned_spawn_transform.get_rotation()
		arena_session_state.set_peer_authoritative_state(
			peer_id, assigned_spawn_position, assigned_spawn_rotation, Vector2.ZERO
		)
		print("[server] join_arena peer=%d player=%s" % [peer_id, cleaned_player_name])
		print(
			(
				"[server][arena] player_joined peer=%d spawn_id=%s active_players=%d/%d"
				% [
					peer_id,
					assigned_spawn_id,
					arena_session_state.get_player_count(),
					arena_session_state.max_players,
				]
			)
		)
		print(
			(
				"[server][join] ack_join_arena peer=%d success=true spawn_pos=%s spawn_rot=%.4f"
				% [peer_id, assigned_spawn_position, assigned_spawn_rotation]
			)
		)
		_join_arena_ack.rpc_id(
			peer_id, true, join_message, assigned_spawn_position, assigned_spawn_rotation
		)
		_broadcast_state_snapshot(0)
	else:
		print("[server][join] reject_join_arena peer=%d reason=%s" % [peer_id, join_message])
		print("[server][join] ack_join_arena peer=%d success=false" % peer_id)
		_join_arena_ack.rpc_id(peer_id, false, join_message, Vector2.ZERO, 0.0)


func _assign_random_available_spawn_id(peer_id: int) -> StringName:
	var available_spawn_ids: Array[StringName] = []
	for spawn_id_variant: Variant in arena_spawn_transforms_by_id.keys():
		var spawn_id: StringName = spawn_id_variant
		if occupied_spawn_peer_by_id.has(spawn_id):
			continue
		available_spawn_ids.append(spawn_id)

	if available_spawn_ids.is_empty():
		return StringName()

	available_spawn_ids.shuffle()
	var selected_spawn_id: StringName = available_spawn_ids[0]
	occupied_spawn_peer_by_id[selected_spawn_id] = peer_id
	return selected_spawn_id


func _release_spawn_id(spawn_id: StringName, peer_id: int) -> void:
	if not occupied_spawn_peer_by_id.has(spawn_id):
		return
	var occupied_peer_id: int = int(occupied_spawn_peer_by_id[spawn_id])
	if occupied_peer_id != peer_id:
		return
	occupied_spawn_peer_by_id.erase(spawn_id)
	print("[server][arena] released_spawn spawn_id=%s peer=%d" % [spawn_id, peer_id])


func on_server_tick(server_tick: int, tick_delta_seconds: float) -> void:
	total_on_server_tick_calls += 1
	if not multiplayer.is_server():
		return
	if arena_session_state == null:
		return
	if arena_session_state.get_player_count() == 0:
		return
	total_on_server_tick_active_calls += 1
	_simulate_authoritative_state(tick_delta_seconds)
	if server_tick % snapshot_interval_ticks == 0:
		total_snapshot_gate_hits += 1
		_broadcast_state_snapshot(server_tick)


func _simulate_authoritative_state(delta_seconds: float) -> void:
	var peer_ids: Array[int] = arena_session_state.get_peer_ids()
	for peer_id: int in peer_ids:
		var peer_state: Dictionary = arena_session_state.get_peer_state(peer_id)
		if peer_state.is_empty():
			continue
		var throttle: float = float(peer_state.get("input_throttle", 0.0))
		var steer: float = float(peer_state.get("input_steer", 0.0))
		var current_rotation: float = float(peer_state.get("state_rotation", 0.0))
		var current_velocity: Vector2 = peer_state.get("state_linear_velocity", Vector2.ZERO)
		var current_position: Vector2 = peer_state.get("state_position", Vector2.ZERO)

		current_rotation += steer * MultiplayerProtocolData.SIM_TURN_RATE_RADIANS * delta_seconds
		var forward_direction: Vector2 = Vector2.RIGHT.rotated(current_rotation)
		var target_velocity: Vector2 = (
			forward_direction * throttle * MultiplayerProtocolData.SIM_MAX_LINEAR_SPEED
		)
		current_velocity = current_velocity.move_toward(
			target_velocity, MultiplayerProtocolData.SIM_ACCELERATION * delta_seconds
		)
		current_position += current_velocity * delta_seconds

		arena_session_state.set_peer_authoritative_state(
			peer_id, current_position, current_rotation, current_velocity
		)


func _build_player_state_snapshot() -> Array[Dictionary]:
	var snapshot_player_states: Array[Dictionary] = []
	var peer_ids: Array[int] = arena_session_state.get_peer_ids()
	for peer_id: int in peer_ids:
		var peer_state: Dictionary = arena_session_state.get_peer_state(peer_id)
		if peer_state.is_empty():
			continue
		(
			snapshot_player_states
			. append(
				{
					"peer_id": peer_id,
					"player_name": str(peer_state.get("player_name", "")),
					"position": peer_state.get("state_position", Vector2.ZERO),
					"rotation": float(peer_state.get("state_rotation", 0.0)),
					"linear_velocity": peer_state.get("state_linear_velocity", Vector2.ZERO),
					"last_processed_input_tick": int(peer_state.get("last_input_tick", 0)),
				}
			)
		)
	return snapshot_player_states


func _broadcast_state_snapshot(server_tick: int) -> void:
	var snapshot_player_states: Array[Dictionary] = _build_player_state_snapshot()
	var connected_peers: PackedInt32Array = multiplayer.get_peers()
	total_snapshots_broadcast += 1
	last_snapshot_tick = server_tick
	for peer_id: int in connected_peers:
		_receive_state_snapshot.rpc_id(peer_id, server_tick, snapshot_player_states)


@rpc("authority", "reliable")
func _receive_server_hello_ack(server_protocol_version: int, server_unix_time: int) -> void:
	# This method exists so RPC path signatures stay valid on both peers.
	push_warning(
		(
			"[server] unexpected server_hello_ack protocol=%d server_time=%d"
			% [server_protocol_version, server_unix_time]
		)
	)


@rpc("authority", "reliable")
func _receive_state_snapshot(server_tick: int, player_states: Array) -> void:
	# This method exists so RPC path signatures stay valid on both peers.
	push_warning(
		"[server] unexpected state_snapshot tick=%d states=%d" % [server_tick, player_states.size()]
	)


@rpc("any_peer", "call_remote", "unreliable_ordered", RPC_CHANNEL_INPUT)
func _receive_input_intent(
	input_tick: int, throttle: float, steer: float, turret_aim: float, fire_pressed: bool
) -> void:
	if not multiplayer.is_server():
		return
	if arena_session_state == null:
		return
	total_input_messages_received += 1
	var peer_id: int = multiplayer.get_remote_sender_id()
	if not arena_session_state.has_peer(peer_id):
		return
	if input_tick <= 0:
		return
	var current_server_tick: int = int(Time.get_ticks_msec())
	var is_too_far_future: bool = (
		input_tick
		> (
			arena_session_state.get_peer_last_input_tick(peer_id)
			+ MultiplayerProtocolData.MAX_INPUT_FUTURE_TICKS
		)
	)
	if is_too_far_future:
		print("[server][sync][input] ignored_far_future peer=%d tick=%d" % [peer_id, input_tick])
		return
	var accepted: bool = arena_session_state.set_peer_input_intent(
		peer_id,
		input_tick,
		clamp(throttle, -1.0, 1.0),
		clamp(steer, -1.0, 1.0),
		clamp(turret_aim, -1.0, 1.0),
		fire_pressed,
		current_server_tick
	)
	if not accepted:
		print("[server][sync][input] ignored_non_monotonic peer=%d tick=%d" % [peer_id, input_tick])
		return
	total_input_messages_applied += 1


func get_debug_sync_metrics() -> Dictionary:
	return {
		"snapshot_interval_ticks": snapshot_interval_ticks,
		"total_on_server_tick_calls": total_on_server_tick_calls,
		"total_on_server_tick_active_calls": total_on_server_tick_active_calls,
		"total_snapshot_gate_hits": total_snapshot_gate_hits,
		"total_input_messages_received": total_input_messages_received,
		"total_input_messages_applied": total_input_messages_applied,
		"total_snapshots_broadcast": total_snapshots_broadcast,
		"last_snapshot_tick": last_snapshot_tick,
	}


@rpc("authority", "reliable")
func _join_arena_ack(
	success: bool, message: String, spawn_position: Vector2, spawn_rotation: float
) -> void:
	# This method exists so RPC path signatures stay valid on both peers.
	push_warning(
		(
			"[server] unexpected join_arena_ack success=%s message=%s spawn_position=%s spawn_rotation=%.4f"
			% [success, message, spawn_position, spawn_rotation]
		)
	)
