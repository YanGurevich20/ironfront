class_name ArenaMatch
extends Node

signal local_player_destroyed
signal local_player_respawned

const ARENA_LEVEL_SCENE: PackedScene = preload("res://src/levels/arena/arena_level_mvp.tscn")

var level_container: Node2D
var arena_level: ArenaLevelMvp
var local_player_tank: Tank
var local_player_dead: bool = false
var log_context: Dictionary = {}
var _debug_set_input_log_count: int = 0

@onready var replication: ArenaReplication = %Replication
@onready var shells: ArenaShells = %Shells


func _ready() -> void:
	shells.bind_replication(replication)


func configure_level_container(next_level_container: Node2D) -> void:
	level_container = next_level_container


func configure_log_context(next_log_context: Dictionary) -> void:
	log_context = next_log_context.duplicate(true)
	replication.configure_log_context(log_context)
	shells.configure_log_context(log_context)


func start_match(spawn_position: Vector2, spawn_rotation: float) -> bool:
	assert(level_container != null, "ArenaMatch requires level_container")
	stop_match()
	print(
		(
			"%s start_match spawn_pos=%s spawn_rot=%.3f level_container=%s children=%d"
			% [
				_log_prefix(),
				spawn_position,
				spawn_rotation,
				level_container.get_path(),
				level_container.get_child_count()
			]
		)
	)
	var level_node: Node = ARENA_LEVEL_SCENE.instantiate()
	var next_arena_level: ArenaLevelMvp = level_node as ArenaLevelMvp
	if next_arena_level == null:
		push_error("%s arena scene root must use ArenaLevelMvp script" % _log_prefix())
		level_node.queue_free()
		return false
	var spawned_player_tank: Tank = PlayerProfileUtils.create_local_player_tank(
		TankManager.TankControllerType.MULTIPLAYER
	)
	if spawned_player_tank == null:
		next_arena_level.queue_free()
		return false
	level_container.add_child(next_arena_level)
	next_arena_level.add_child(spawned_player_tank)
	spawned_player_tank.apply_spawn_state(spawn_position, spawn_rotation)
	print(
		(
			"%s local_tank_spawned tank=%s visible=%s inside_tree=%s parent=%s pos=%s rot=%.3f"
			% [
				_log_prefix(),
				str(spawned_player_tank.get_instance_id()),
				str(spawned_player_tank.visible),
				str(spawned_player_tank.is_inside_tree()),
				str(spawned_player_tank.get_parent().get_path()),
				spawned_player_tank.global_position,
				spawned_player_tank.global_rotation,
			]
		)
	)
	arena_level = next_arena_level
	local_player_tank = spawned_player_tank
	print(
		(
			"%s local_tank_visual z_index=%d z_as_relative=%s top_level=%s modulate=%s"
			% [
				_log_prefix(),
				local_player_tank.z_index,
				str(local_player_tank.z_as_relative),
				str(local_player_tank.top_level),
				str(local_player_tank.modulate),
			]
		)
	)
	local_player_dead = false
	_debug_set_input_log_count = 0
	replication.start_match(arena_level, local_player_tank)
	shells.start_match(arena_level, local_player_tank)
	if not GameplayBus.tank_destroyed.is_connected(_on_tank_destroyed):
		GameplayBus.tank_destroyed.connect(_on_tank_destroyed)
	get_tree().set_pause(false)
	return true


func stop_match() -> void:
	if GameplayBus.tank_destroyed.is_connected(_on_tank_destroyed):
		GameplayBus.tank_destroyed.disconnect(_on_tank_destroyed)
	local_player_dead = false
	_debug_set_input_log_count = 0
	shells.stop_match()
	replication.stop_match()
	if local_player_tank != null:
		local_player_tank.queue_free()
		local_player_tank = null
	if arena_level != null:
		arena_level.queue_free()
		arena_level = null


func is_local_player_dead() -> bool:
	return local_player_dead


func apply_state_snapshot(server_tick: int, player_states: Array) -> void:
	replication.on_state_snapshot_received(server_tick, player_states)


func handle_remote_respawn_received(
	peer_id: int, player_name: String, spawn_position: Vector2, spawn_rotation: float
) -> void:
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
	if local_player_dead:
		return
	local_player_tank.left_track_input = left_track_input
	local_player_tank.right_track_input = right_track_input
	local_player_tank.turret_rotation_input = turret_rotation_input
	if _debug_set_input_log_count < 12:
		_debug_set_input_log_count += 1
		print(
			(
				"%s set_local_input left=%.2f right=%.2f turret=%.2f tank=%s"
				% [
					_log_prefix(),
					left_track_input,
					right_track_input,
					turret_rotation_input,
					str(local_player_tank.get_instance_id())
				]
			)
		)


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
	print(
		(
			"%s local_tank_respawned tank=%s visible=%s inside_tree=%s pos=%s rot=%.3f"
			% [
				_log_prefix(),
				str(respawned_tank.get_instance_id()),
				str(respawned_tank.visible),
				str(respawned_tank.is_inside_tree()),
				respawned_tank.global_position,
				respawned_tank.global_rotation,
			]
		)
	)
	local_player_tank = respawned_tank
	local_player_dead = false
	replication.replace_local_player_tank(local_player_tank)
	shells.replace_local_player_tank(local_player_tank)
	local_player_respawned.emit()


func _on_tank_destroyed(tank: Tank) -> void:
	if tank != local_player_tank:
		return
	local_player_dead = true
	local_player_destroyed.emit()


func _log_prefix() -> String:
	var process_id: int = int(log_context.get("process_id", OS.get_process_id()))
	var peer_id: int = int(log_context.get("peer_id", 0))
	return "[client-match pid=%d peer=%d]" % [process_id, peer_id]
