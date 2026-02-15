class_name ArenaWorld
extends Node

signal local_player_destroyed
signal local_player_respawned

var arena_level: ArenaLevelMvp
var local_player_tank: Tank
var local_player_dead: bool = false
var level_container: Node2D
var arena_scene: PackedScene = preload("res://src/levels/arena/arena_level_mvp.tscn")

@onready var replication: ArenaWorldReplication = %Replication
@onready var shells: ArenaWorldShells = %Shells


func _ready() -> void:
	Utils.connect_checked(GameplayBus.tank_destroyed, _on_tank_destroyed)
	shells.configure(replication)


func configure_level_container(next_level_container: Node2D) -> void:
	level_container = next_level_container


func is_local_player_dead() -> bool:
	return local_player_dead


func activate(spawn_position: Vector2, spawn_rotation: float) -> bool:
	assert(level_container != null, "ArenaWorld requires level_container")
	deactivate()
	var arena_level_node: Node = arena_scene.instantiate()
	var arena_level_candidate: ArenaLevelMvp = arena_level_node as ArenaLevelMvp
	if arena_level_candidate == null:
		push_error("%s arena scene root must use ArenaLevelMvp script" % _log_prefix())
		arena_level_node.queue_free()
		return false
	level_container.add_child(arena_level_candidate)
	arena_level = arena_level_candidate
	var spawned_player_tank: Tank = PlayerProfileUtils.create_local_player_tank(
		TankManager.TankControllerType.MULTIPLAYER
	)
	if spawned_player_tank == null:
		deactivate()
		return false
	arena_level.add_child(spawned_player_tank)
	spawned_player_tank.apply_spawn_state(spawn_position, spawn_rotation)
	local_player_tank = spawned_player_tank
	local_player_dead = false
	replication.start_runtime(arena_level, local_player_tank)
	shells.start_runtime(arena_level, local_player_tank)
	get_tree().set_pause(false)
	return true


func deactivate() -> void:
	local_player_dead = false
	shells.stop_runtime()
	replication.stop_runtime()
	if local_player_tank != null:
		local_player_tank.queue_free()
		local_player_tank = null
	if arena_level != null:
		level_container.remove_child(arena_level)
		arena_level.queue_free()
		arena_level = null


func apply_state_snapshot(server_tick: int, player_states: Array) -> void:
	replication.on_state_snapshot_received(server_tick, player_states)


func handle_remote_respawn_received(
	peer_id: int, player_name: String, spawn_position: Vector2, spawn_rotation: float
) -> void:
	if arena_level == null:
		return
	if peer_id == multiplayer.get_unique_id():
		_respawn_local_player_tank(spawn_position, spawn_rotation)
		return
	replication.respawn_remote_tank(peer_id, player_name, spawn_position, spawn_rotation)


func handle_shell_spawn_received(
	shot_id: int,
	firing_peer_id: int,
	shell_id: String,
	spawn_position: Vector2,
	shell_velocity: Vector2,
	shell_rotation: float
) -> void:
	shells.handle_shell_spawn_received(
		shot_id, firing_peer_id, shell_id, spawn_position, shell_velocity, shell_rotation
	)


func handle_shell_impact_received(
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
	shells.handle_shell_impact_received(
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


func handle_loadout_state_received(
	selected_shell_id: String, shell_counts_by_id: Dictionary, reload_time_left: float
) -> void:
	shells.handle_loadout_state_received(selected_shell_id, shell_counts_by_id, reload_time_left)


func set_local_input(
	left_track_input: float, right_track_input: float, turret_rotation_input: float
) -> void:
	if arena_level == null or local_player_dead:
		return
	local_player_tank.left_track_input = left_track_input
	local_player_tank.right_track_input = right_track_input
	local_player_tank.turret_rotation_input = turret_rotation_input


func _respawn_local_player_tank(spawn_position: Vector2, spawn_rotation: float) -> void:
	local_player_tank.queue_free()
	var respawned_tank: Tank = PlayerProfileUtils.create_local_player_tank(
		TankManager.TankControllerType.MULTIPLAYER
	)
	if respawned_tank == null:
		push_error("%s arena_respawn_failed player_tank_creation" % _log_prefix())
		return
	arena_level.add_child(respawned_tank)
	respawned_tank.apply_spawn_state(spawn_position, spawn_rotation)
	local_player_tank = respawned_tank
	local_player_dead = false
	replication.replace_local_player_tank(local_player_tank)
	shells.replace_local_player_tank(local_player_tank)
	local_player_respawned.emit()


func _on_tank_destroyed(tank: Tank) -> void:
	if arena_level == null or tank != local_player_tank:
		return
	local_player_dead = true
	local_player_destroyed.emit()


func _log_prefix() -> String:
	var peer_id: int = 0
	if multiplayer.multiplayer_peer != null:
		peer_id = multiplayer.get_unique_id()
	return "[client-world pid=%d peer=%d]" % [OS.get_process_id(), peer_id]
