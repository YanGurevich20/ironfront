class_name ArenaSimulation
extends Node

var runtime: ArenaRuntime
var actors: ArenaActors


func configure(next_runtime: ArenaRuntime, next_actors: ArenaActors) -> void:
	runtime = next_runtime
	actors = next_actors


func step_authoritative_runtime(
	next_arena_session_state: ArenaSessionState, delta: float
) -> Array[Dictionary]:
	var snapshot_actor_states: Array[Dictionary] = []
	actors.update_pending_bot_respawns(delta)
	var peer_ids: Array[int] = next_arena_session_state.get_peer_ids()
	for peer_id: int in peer_ids:
		var spawned_tank: Tank = actors.actor_tanks_by_id.get(peer_id)
		if spawned_tank == null:
			continue
		var peer_state: Dictionary = next_arena_session_state.get_peer_state(peer_id)
		if peer_state.is_empty():
			spawned_tank.reset_input()
			continue
		if spawned_tank._health > 0:
			_apply_peer_input_intent_to_tank(
				next_arena_session_state, peer_id, spawned_tank, peer_state
			)
		else:
			spawned_tank.reset_input()
		_update_peer_authoritative_state(next_arena_session_state, peer_id, spawned_tank)
	var actor_ids: Array[int] = actors.actor_tanks_by_id.keys()
	actor_ids.sort()
	for actor_id: int in actor_ids:
		var actor_tank: Tank = actors.actor_tanks_by_id.get(actor_id)
		if actor_tank == null:
			continue
		var actor_metadata: Dictionary = actors.actor_metadata_by_id.get(actor_id, {})
		var is_bot: bool = bool(actor_metadata.get("is_bot", false))
		var player_name: String = actors.get_actor_player_name(actor_id)
		var last_processed_input_tick: int = 0
		if not is_bot:
			var peer_state: Dictionary = next_arena_session_state.get_peer_state(actor_id)
			last_processed_input_tick = int(peer_state.get("last_input_tick", 0))
		(
			snapshot_actor_states
			. append(
				{
					"peer_id": actor_id,
					"player_name": player_name,
					"position": actor_tank.global_position,
					"rotation": actor_tank.global_rotation,
					"linear_velocity": actor_tank.linear_velocity,
					"turret_rotation": actor_tank.turret.rotation,
					"last_processed_input_tick": last_processed_input_tick,
					"is_bot": is_bot,
					"is_alive": actor_tank._health > 0,
				}
			)
		)
	return snapshot_actor_states


func _update_peer_authoritative_state(
	next_arena_session_state: ArenaSessionState, peer_id: int, spawned_tank: Tank
) -> void:
	next_arena_session_state.set_peer_authoritative_state(
		peer_id,
		spawned_tank.global_position,
		spawned_tank.global_rotation,
		spawned_tank.linear_velocity,
		spawned_tank.turret.rotation
	)


func _apply_peer_input_intent_to_tank(
	next_arena_session_state: ArenaSessionState,
	peer_id: int,
	spawned_tank: Tank,
	peer_state: Dictionary
) -> void:
	var left_track_input: float = clamp(float(peer_state.get("input_left_track", 0.0)), -1.0, 1.0)
	var right_track_input: float = clamp(float(peer_state.get("input_right_track", 0.0)), -1.0, 1.0)
	var turret_aim: float = clamp(float(peer_state.get("input_turret_aim", 0.0)), -1.0, 1.0)
	spawned_tank.left_track_input = left_track_input
	spawned_tank.right_track_input = right_track_input
	spawned_tank.turret_rotation_input = turret_aim
	var shell_select_request: Dictionary = (
		next_arena_session_state.consume_peer_shell_select_request(peer_id)
	)
	if not shell_select_request.is_empty():
		ArenaLoadoutAuthorityUtils.handle_peer_shell_select_request(
			runtime, next_arena_session_state, peer_id, spawned_tank, shell_select_request
		)
	var fire_request_seq: int = next_arena_session_state.consume_peer_fire_request_seq(peer_id)
	if fire_request_seq > 0:
		ArenaLoadoutAuthorityUtils.handle_peer_fire_request(
			runtime, next_arena_session_state, peer_id, spawned_tank
		)
