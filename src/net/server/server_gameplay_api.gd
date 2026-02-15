class_name ServerGameplayApi
extends Node

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
	var snapshot_player_states: Array[Dictionary] = _build_player_states_snapshot()
	var arena_max_players: int = arena_session_state.max_players
	var connected_peers: PackedInt32Array = multiplayer.get_peers()
	total_snapshots_broadcast += 1
	last_snapshot_tick = server_tick
	for peer_id: int in connected_peers:
		_receive_state_snapshot.rpc_id(
			peer_id, server_tick, snapshot_player_states, arena_max_players
		)


func broadcast_state_snapshot_now() -> void:
	_broadcast_state_snapshot(0)


@rpc("authority", "reliable")
func _receive_state_snapshot(_server_tick: int, _player_states: Array, _max_players: int) -> void:
	push_warning("[server][gameplay] unexpected RPC: _receive_state_snapshot")


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
func _receive_arena_shell_spawn(
	_shot_id: int,
	_firing_peer_id: int,
	_shell_spec_path: String,
	_spawn_position: Vector2,
	_shell_velocity: Vector2,
	_shell_rotation: float
) -> void:
	push_warning("[server][gameplay] unexpected RPC: _receive_arena_shell_spawn")


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
	push_warning("[server][gameplay] unexpected RPC: _receive_arena_shell_impact")


@rpc("authority", "reliable")
func _receive_arena_respawn(
	_peer_id: int, _player_name: String, _spawn_position: Vector2, _spawn_rotation: float
) -> void:
	push_warning("[server][gameplay] unexpected RPC: _receive_arena_respawn")


@rpc("authority", "reliable")
func _receive_arena_fire_rejected(_reason: String) -> void:
	push_warning("[server][gameplay] unexpected RPC: _receive_arena_fire_rejected")


@rpc("authority", "reliable")
func _receive_arena_loadout_state(
	_selected_shell_path: String, _shell_counts_by_path: Dictionary, _reload_time_left: float
) -> void:
	push_warning("[server][gameplay] unexpected RPC: _receive_arena_loadout_state")


@rpc("authority", "reliable")
func _receive_arena_kill_event(_kill_event_payload: Dictionary) -> void:
	push_warning("[server][gameplay] unexpected RPC: _receive_arena_kill_event")


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


func mark_input_applied() -> void:
	total_input_messages_applied += 1


func mark_fire_request_applied() -> void:
	total_fire_requests_applied += 1


func broadcast_arena_shell_spawn(
	shot_id: int,
	firing_peer_id: int,
	shell_spec_path: String,
	spawn_position: Vector2,
	shell_velocity: Vector2,
	shell_rotation: float
) -> void:
	for peer_id: int in multiplayer.get_peers():
		_receive_arena_shell_spawn.rpc_id(
			peer_id,
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
	for peer_id: int in multiplayer.get_peers():
		_receive_arena_shell_impact.rpc_id(
			peer_id,
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


func broadcast_arena_kill_event(
	event_seq: int,
	killer_peer_id: int,
	killer_name: String,
	killer_tank_name: String,
	shell_short_name: String,
	victim_peer_id: int,
	victim_name: String,
	victim_tank_name: String
) -> void:
	var kill_event_payload: Dictionary = {
		"event_seq": event_seq,
		"killer_peer_id": killer_peer_id,
		"killer_name": killer_name,
		"killer_tank_name": killer_tank_name,
		"shell_short_name": shell_short_name,
		"victim_peer_id": victim_peer_id,
		"victim_name": victim_name,
		"victim_tank_name": victim_tank_name,
	}
	for peer_id: int in multiplayer.get_peers():
		_receive_arena_kill_event.rpc_id(peer_id, kill_event_payload)


func _build_player_states_snapshot() -> Array[Dictionary]:
	if not authoritative_player_states.is_empty():
		var runtime_snapshot_player_states: Array[Dictionary] = []
		for player_state: Dictionary in authoritative_player_states:
			runtime_snapshot_player_states.append(player_state.duplicate(true))
		return runtime_snapshot_player_states

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
					"player_name": peer_state.get("player_name", ""),
					"position": peer_state.get("state_position", Vector2.ZERO),
					"rotation": peer_state.get("state_rotation", 0.0),
					"linear_velocity": peer_state.get("state_linear_velocity", Vector2.ZERO),
					"turret_rotation": peer_state.get("state_turret_rotation", 0.0),
					"last_processed_input_tick": peer_state.get("last_input_tick", 0),
					"is_bot": false,
					"is_alive": true,
				}
			)
		)
	return snapshot_player_states
