class_name NetworkServer
extends Node

signal arena_join_succeeded(
	peer_id: int, player_name: String, spawn_id: StringName, spawn_transform: Transform2D
)
signal arena_peer_removed(peer_id: int, reason: String)

const MultiplayerProtocolData := preload("res://net/multiplayer_protocol.gd")
const NetworkServerSnapshotBuilderData := preload("res://net/network_server_snapshot_builder.gd")
const RPC_CHANNEL_INPUT: int = 1
const RPC_CHANNEL_STATE: int = 2

var server_peer: ENetMultiplayerPeer
var protocol_version: int = MultiplayerProtocolData.PROTOCOL_VERSION
var arena_session_state: ArenaSessionState
var arena_spawn_transforms_by_id: Dictionary[StringName, Transform2D] = {}
var occupied_spawn_peer_by_id: Dictionary[StringName, int] = {}
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
	Utils.connect_checked(multiplayer.peer_disconnected, _on_peer_disconnected)

	print("[server] listening on udp://0.0.0.0:%d max_clients=%d" % [listen_port, max_clients])
	return true


func _on_peer_disconnected(peer_id: int) -> void:
	print("[server] peer_disconnected id=%d peers=%d" % [peer_id, multiplayer.get_peers().size()])
	if arena_session_state == null:
		push_warning("[server][arena] missing session state during disconnect")
		return
	var remove_result: Dictionary = arena_session_state.remove_peer(peer_id, "PEER_DISCONNECTED")
	if remove_result.get("removed", false):
		var released_spawn_id: StringName = remove_result.get("spawn_id", StringName())
		if released_spawn_id != StringName():
			_release_spawn_id(released_spawn_id, peer_id)
		arena_peer_removed.emit(peer_id, "PEER_DISCONNECTED")
		print("[server][arena] peer_disconnected_cleanup peer=%d" % peer_id)


func _warn_unexpected_rpc(method_name: String, rpc_args: Array) -> void:
	if not rpc_args.is_empty():
		push_warning("[server] unexpected RPC: %s" % method_name)


@rpc("authority", "reliable")
func _receive_server_hello_ack(server_protocol_version: int, server_unix_time: int) -> void:
	_warn_unexpected_rpc("_receive_server_hello_ack", [server_protocol_version, server_unix_time])


@rpc("any_peer", "reliable")
func _receive_client_hello(client_protocol_version: int, player_name: String) -> void:
	var peer_id: int = multiplayer.get_remote_sender_id()
	print(
		(
			"[server][join] receive_client_hello peer=%d protocol=%d"
			% [peer_id, client_protocol_version]
		)
	)
	print("[server] client_hello peer=%d player=%s" % [peer_id, player_name])
	_receive_server_hello_ack.rpc_id(peer_id, protocol_version, Time.get_unix_time_from_system())


@rpc("any_peer", "reliable")
func _join_arena(player_name: String) -> void:
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
	if arena_session_state.has_peer(peer_id):
		var previous_spawn_id: StringName = arena_session_state.get_peer_spawn_id(peer_id)
		arena_session_state.remove_peer(peer_id, "REJOIN_REQUEST")
		if previous_spawn_id != StringName():
			_release_spawn_id(previous_spawn_id, peer_id)
	var cleaned_player_name: String = player_name.strip_edges()
	print("[server][join] receive_join_arena peer=%d player=%s" % [peer_id, cleaned_player_name])
	if cleaned_player_name.is_empty():
		print("[server][join] reject_join_arena peer=%d reason=INVALID_PLAYER_NAME" % peer_id)
		_join_arena_ack.rpc_id(peer_id, false, "INVALID PLAYER NAME", Vector2.ZERO, 0.0)
		return
	var join_result: Dictionary = arena_session_state.try_join_peer(peer_id, cleaned_player_name)
	var join_success: bool = join_result.get("success", false)
	var join_message: String = join_result.get("message", "JOIN FAILED")
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
		arena_join_succeeded.emit(
			peer_id, cleaned_player_name, assigned_spawn_id, assigned_spawn_transform
		)
		print("[server] join_arena peer=%d player=%s" % [peer_id, cleaned_player_name])
		print(
			(
				"[server][arena] player_joined peer=%d spawn_id=%s active_players=%d/%d"
				% [
					peer_id,
					assigned_spawn_id,
					arena_session_state.get_player_count(),
					arena_session_state.max_players
				]
			)
		)
		_join_arena_ack.rpc_id(
			peer_id, true, join_message, assigned_spawn_position, assigned_spawn_rotation
		)
		_broadcast_state_snapshot(0)
	else:
		print("[server][join] reject_join_arena peer=%d reason=%s" % [peer_id, join_message])
		_join_arena_ack.rpc_id(peer_id, false, join_message, Vector2.ZERO, 0.0)


@rpc("authority", "reliable")
func _receive_state_snapshot(server_tick: int, player_states: Array) -> void:
	_warn_unexpected_rpc("_receive_state_snapshot", [server_tick, player_states])


func _assign_random_available_spawn_id(peer_id: int) -> StringName:
	var available_spawn_ids: Array[StringName] = []
	for spawn_id: StringName in arena_spawn_transforms_by_id.keys():
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
	var occupied_peer_id: int = occupied_spawn_peer_by_id[spawn_id]
	if occupied_peer_id != peer_id:
		return
	occupied_spawn_peer_by_id.erase(spawn_id)
	print("[server][arena] released_spawn spawn_id=%s peer=%d" % [spawn_id, peer_id])


func on_server_tick(server_tick: int, tick_delta_seconds: float) -> void:
	total_on_server_tick_calls += 1
	if tick_delta_seconds <= 0.0:
		return
	if arena_session_state == null:
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
		NetworkServerSnapshotBuilderData
		. build_player_states_snapshot(arena_session_state, authoritative_player_states)
	)
	var connected_peers: PackedInt32Array = multiplayer.get_peers()
	total_snapshots_broadcast += 1
	last_snapshot_tick = server_tick
	for peer_id: int in connected_peers:
		_receive_state_snapshot.rpc_id(peer_id, server_tick, snapshot_player_states)


func broadcast_arena_shell_spawn(
	shot_id: int,
	firing_peer_id: int,
	shell_spec_path: String,
	spawn_position: Vector2,
	shell_velocity: Vector2,
	shell_rotation: float
) -> void:
	var connected_peers: PackedInt32Array = multiplayer.get_peers()
	for peer_id: int in connected_peers:
		rpc_id(
			peer_id,
			"_receive_arena_shell_spawn",
			shot_id,
			firing_peer_id,
			shell_spec_path,
			spawn_position,
			shell_velocity,
			shell_rotation
		)


func broadcast_arena_shell_impact(
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
	var connected_peers: PackedInt32Array = multiplayer.get_peers()
	for peer_id: int in connected_peers:
		rpc_id(
			peer_id,
			"_receive_arena_shell_impact",
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


@rpc("any_peer", "call_remote", "unreliable_ordered", RPC_CHANNEL_INPUT)
func _receive_input_intent(
	input_tick: int, left_track_input: float, right_track_input: float, turret_aim: float
) -> void:
	if arena_session_state == null:
		return
	total_input_messages_received += 1
	var peer_id: int = multiplayer.get_remote_sender_id()
	if not arena_session_state.has_peer(peer_id):
		return
	if input_tick <= 0:
		return
	var current_server_tick: int = Time.get_ticks_msec()
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
		clamp(left_track_input, -1.0, 1.0),
		clamp(right_track_input, -1.0, 1.0),
		clamp(turret_aim, -1.0, 1.0),
		current_server_tick
	)
	if not accepted:
		print("[server][sync][input] ignored_non_monotonic peer=%d tick=%d" % [peer_id, input_tick])
		return
	total_input_messages_applied += 1


@rpc("any_peer", "reliable")
func _request_fire(fire_request_seq: int) -> void:
	if arena_session_state == null:
		return
	total_fire_requests_received += 1
	var peer_id: int = multiplayer.get_remote_sender_id()
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
	total_fire_requests_applied += 1


@rpc("authority", "reliable")
func _join_arena_ack(
	success: bool, message: String, spawn_position: Vector2, spawn_rotation: float
) -> void:
	_warn_unexpected_rpc("_join_arena_ack", [success, message, spawn_position, spawn_rotation])


@rpc("authority", "reliable")
func _receive_arena_shell_spawn(
	shot_id: int,
	firing_peer_id: int,
	shell_spec_path: String,
	spawn_position: Vector2,
	shell_velocity: Vector2,
	shell_rotation: float
) -> void:
	_warn_unexpected_rpc(
		"_receive_arena_shell_spawn",
		[shot_id, firing_peer_id, shell_spec_path, spawn_position, shell_velocity, shell_rotation]
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
	_warn_unexpected_rpc(
		"_receive_arena_shell_impact",
		[
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
		]
	)
