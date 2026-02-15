class_name ClientGameplayApi
extends Node

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
signal arena_kill_event_received(kill_event_payload: Dictionary)

const RPC_CHANNEL_INPUT: int = 1


func send_input_intent(
	input_tick: int, left_track_input: float, right_track_input: float, turret_aim: float
) -> void:
	_receive_input_intent.rpc_id(1, input_tick, left_track_input, right_track_input, turret_aim)


func request_fire(fire_request_seq: int) -> void:
	_request_fire.rpc_id(1, fire_request_seq)


func request_shell_select(shell_select_seq: int, shell_spec_path: String) -> void:
	_request_shell_select.rpc_id(1, shell_select_seq, shell_spec_path)


func request_respawn() -> void:
	_request_respawn.rpc_id(1)


@rpc("authority", "reliable")
func _receive_state_snapshot(server_tick: int, player_states: Array, max_players: int) -> void:
	state_snapshot_received.emit(server_tick, player_states, max_players)


@rpc("any_peer", "call_remote", "unreliable_ordered", RPC_CHANNEL_INPUT)
func _receive_input_intent(
	_input_tick: int, _left_track_input: float, _right_track_input: float, _turret_aim: float
) -> void:
	push_warning("[client][gameplay] unexpected RPC: _receive_input_intent")


@rpc("any_peer", "reliable")
func _request_fire(_fire_request_seq: int) -> void:
	push_warning("[client][gameplay] unexpected RPC: _request_fire")


@rpc("any_peer", "reliable")
func _request_shell_select(_shell_select_seq: int, _shell_spec_path: String) -> void:
	push_warning("[client][gameplay] unexpected RPC: _request_shell_select")


@rpc("any_peer", "reliable")
func _request_respawn() -> void:
	push_warning("[client][gameplay] unexpected RPC: _request_respawn")


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
	arena_kill_event_received.emit(kill_event_payload)
