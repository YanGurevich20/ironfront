class_name ServerArenaRuntime
extends Node

var network_gameplay: ServerGameplayApi
var arena_session_state: ArenaSessionState

@onready var actors: ArenaActors = %Actors
@onready var simulation: ArenaSimulation = %Simulation
@onready var shell_controller: ArenaServerShellController = %ShellController


func _ready() -> void:
	actors.configure(self)
	simulation.configure(self, actors)
	shell_controller.configure(self, actors)


func configure_network_gameplay(next_network_gameplay: ServerGameplayApi) -> void:
	network_gameplay = next_network_gameplay


func configure_arena_session(next_arena_session_state: ArenaSessionState) -> void:
	arena_session_state = next_arena_session_state


func configure_bot_settings(next_bot_count: int, next_bot_respawn_delay_seconds: float) -> void:
	actors.configure_bot_settings(next_bot_count, next_bot_respawn_delay_seconds)


func initialize_runtime(arena_level_packed_scene: PackedScene) -> bool:
	clear_runtime()
	return actors.initialize_runtime(arena_level_packed_scene)


func get_spawn_transforms_by_id() -> Dictionary[StringName, Transform2D]:
	return actors.get_spawn_transforms_by_id()


func spawn_peer_tank_at_random(peer_id: int, player_name: String, tank_id: String) -> Dictionary:
	return actors.spawn_peer_tank_at_random(peer_id, player_name, tank_id)


func respawn_peer_tank_at_random(peer_id: int, player_name: String, tank_id: String) -> Dictionary:
	return actors.respawn_peer_tank_at_random(peer_id, player_name, tank_id)


func despawn_peer_tank(peer_id: int, reason: String) -> void:
	actors.despawn_peer_tank(peer_id, reason)


func step_authoritative_runtime(
	next_arena_session_state: ArenaSessionState, delta: float
) -> Array[Dictionary]:
	return simulation.step_authoritative_runtime(next_arena_session_state, delta)


func clear_runtime() -> void:
	actors.clear_runtime()
	shell_controller.clear_state()


func _exit_tree() -> void:
	clear_runtime()
