class_name ArenaSessionRuntime
extends Node

signal local_player_destroyed
signal local_player_respawned

var gameplay_api: ClientGameplayApi
var enet_client: ENetClient
var level_container: Node2D

@onready var arena_match: ArenaMatch = %ArenaMatch
@onready var input: ArenaInput = %ArenaInput
@onready var rewards: ArenaRewards = %ArenaRewards


func _ready() -> void:
	Utils.connect_checked(arena_match.local_player_destroyed, _on_match_local_player_destroyed)
	Utils.connect_checked(arena_match.local_player_respawned, _on_match_local_player_respawned)


func configure(
	next_gameplay_api: ClientGameplayApi, next_enet_client: ENetClient, next_level_container: Node2D
) -> void:
	gameplay_api = next_gameplay_api
	enet_client = next_enet_client
	level_container = next_level_container


func start_session(spawn_position: Vector2, spawn_rotation: float) -> bool:
	assert(gameplay_api != null, "ArenaSessionRuntime requires ClientGameplayApi")
	assert(enet_client != null, "ArenaSessionRuntime requires ENetClient")
	assert(level_container != null, "ArenaSessionRuntime requires level_container")
	stop_session()
	arena_match.configure_log_context(_build_log_context())
	arena_match.configure_level_container(level_container)
	if not arena_match.start_match(spawn_position, spawn_rotation):
		return false
	input.start_session(gameplay_api, enet_client, arena_match)
	rewards.start_session()
	_connect_gameplay_api_signals()
	GameplayBus.level_started.emit()
	return true


func stop_session() -> void:
	_disconnect_gameplay_api_signals()
	input.stop_session()
	rewards.stop_session()
	arena_match.stop_match()


func request_respawn() -> void:
	if not arena_match.is_local_player_dead():
		return
	if not input.can_send_gameplay_requests():
		return
	gameplay_api.request_respawn()


func build_summary(status_message: String) -> Dictionary:
	return rewards.build_summary(status_message)


func apply_rewards() -> void:
	rewards.apply_rewards()


func _on_state_snapshot_received(server_tick: int, player_states: Array, max_players: int) -> void:
	arena_match.apply_state_snapshot(server_tick, player_states)
	var active_human_players: int = 0
	var active_bots: int = 0
	for player_state_variant: Variant in player_states:
		var player_state: Dictionary = player_state_variant
		if bool(player_state.get("is_bot", false)):
			active_bots += int(bool(player_state.get("is_alive", true)))
			continue
		active_human_players += 1
	GameplayBus.online_player_count_updated.emit(active_human_players, max_players, active_bots)


func _on_arena_fire_rejected_received(reason: String) -> void:
	GameplayBus.online_fire_rejected.emit(reason)


func _on_arena_kill_event_received(kill_event_payload: Dictionary) -> void:
	var event_seq: int = int(kill_event_payload.get("event_seq", 0))
	var killer_peer_id: int = int(kill_event_payload.get("killer_peer_id", 0))
	var killer_name: String = str(kill_event_payload.get("killer_name", ""))
	var killer_tank_name: String = str(kill_event_payload.get("killer_tank_name", ""))
	var shell_short_name: String = str(kill_event_payload.get("shell_short_name", ""))
	var victim_peer_id: int = int(kill_event_payload.get("victim_peer_id", 0))
	var victim_name: String = str(kill_event_payload.get("victim_name", ""))
	var victim_tank_name: String = str(kill_event_payload.get("victim_tank_name", ""))
	var local_peer_id: int = multiplayer.get_unique_id()
	GameplayBus.player_kill_event.emit(
		event_seq,
		killer_name,
		killer_tank_name,
		killer_peer_id == local_peer_id,
		shell_short_name,
		victim_name,
		victim_tank_name,
		victim_peer_id == local_peer_id
	)


func _on_arena_shell_spawn_received(
	shot_id: int,
	firing_peer_id: int,
	shell_id: String,
	spawn_position: Vector2,
	shell_velocity: Vector2,
	shell_rotation: float
) -> void:
	arena_match.handle_shell_spawn_received(
		shot_id, firing_peer_id, shell_id, spawn_position, shell_velocity, shell_rotation
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
	arena_match.handle_shell_impact_received(
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
	peer_id: int,
	player_name: String,
	tank_id: String,
	spawn_position: Vector2,
	spawn_rotation: float
) -> void:
	arena_match.handle_remote_respawn_received(
		peer_id, player_name, tank_id, spawn_position, spawn_rotation
	)


func _on_arena_loadout_state_received(
	selected_shell_id: String, shell_counts_by_id: Dictionary, reload_time_left: float
) -> void:
	arena_match.handle_loadout_state_received(
		selected_shell_id, shell_counts_by_id, reload_time_left
	)


func _on_match_local_player_destroyed() -> void:
	input.stop_session(false)
	local_player_destroyed.emit()


func _on_match_local_player_respawned() -> void:
	input.start_session(gameplay_api, enet_client, arena_match, false)
	local_player_respawned.emit()


func _connect_gameplay_api_signals() -> void:
	Utils.connect_checked(gameplay_api.state_snapshot_received, _on_state_snapshot_received)
	Utils.connect_checked(
		gameplay_api.arena_fire_rejected_received, _on_arena_fire_rejected_received
	)
	Utils.connect_checked(gameplay_api.arena_kill_event_received, _on_arena_kill_event_received)
	Utils.connect_checked(gameplay_api.arena_shell_spawn_received, _on_arena_shell_spawn_received)
	Utils.connect_checked(gameplay_api.arena_shell_impact_received, _on_arena_shell_impact_received)
	Utils.connect_checked(gameplay_api.arena_respawn_received, _on_arena_respawn_received)
	Utils.connect_checked(
		gameplay_api.arena_loadout_state_received, _on_arena_loadout_state_received
	)


func _disconnect_gameplay_api_signals() -> void:
	if gameplay_api.state_snapshot_received.is_connected(_on_state_snapshot_received):
		gameplay_api.state_snapshot_received.disconnect(_on_state_snapshot_received)
	if gameplay_api.arena_fire_rejected_received.is_connected(_on_arena_fire_rejected_received):
		gameplay_api.arena_fire_rejected_received.disconnect(_on_arena_fire_rejected_received)
	if gameplay_api.arena_kill_event_received.is_connected(_on_arena_kill_event_received):
		gameplay_api.arena_kill_event_received.disconnect(_on_arena_kill_event_received)
	if gameplay_api.arena_shell_spawn_received.is_connected(_on_arena_shell_spawn_received):
		gameplay_api.arena_shell_spawn_received.disconnect(_on_arena_shell_spawn_received)
	if gameplay_api.arena_shell_impact_received.is_connected(_on_arena_shell_impact_received):
		gameplay_api.arena_shell_impact_received.disconnect(_on_arena_shell_impact_received)
	if gameplay_api.arena_respawn_received.is_connected(_on_arena_respawn_received):
		gameplay_api.arena_respawn_received.disconnect(_on_arena_respawn_received)
	if gameplay_api.arena_loadout_state_received.is_connected(_on_arena_loadout_state_received):
		gameplay_api.arena_loadout_state_received.disconnect(_on_arena_loadout_state_received)


func _build_log_context() -> Dictionary:
	var peer_id: int = 0
	if multiplayer.multiplayer_peer != null:
		peer_id = multiplayer.get_unique_id()
	return {
		"process_id": OS.get_process_id(),
		"peer_id": peer_id,
	}
