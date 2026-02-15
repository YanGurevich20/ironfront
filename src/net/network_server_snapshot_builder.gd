class_name NetworkServerSnapshotBuilder
extends RefCounted


static func build_player_states_snapshot(
	arena_session_state: ArenaSessionState, authoritative_player_states: Array[Dictionary]
) -> Array[Dictionary]:
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
