class_name ArenaServerShellController
extends Node

var runtime: ServerArenaRuntime
var actors: ArenaActors
var next_shell_shot_id: int = 1
var next_kill_event_seq: int = 1
var shot_id_by_shell_instance_id: Dictionary[int, int] = {}
var firing_actor_id_by_shell_instance_id: Dictionary[int, int] = {}


func _ready() -> void:
	Utils.connect_checked(GameplayBus.shell_fired, _on_shell_fired)


func configure(next_runtime: ServerArenaRuntime, next_actors: ArenaActors) -> void:
	runtime = next_runtime
	actors = next_actors


func clear_state() -> void:
	shot_id_by_shell_instance_id.clear()
	firing_actor_id_by_shell_instance_id.clear()
	next_shell_shot_id = 1
	next_kill_event_seq = 1


func _on_shell_fired(shell: Shell, tank: Tank) -> void:
	var tank_instance_id: int = tank.get_instance_id()
	if not actors.actor_id_by_tank_instance_id.has(tank_instance_id):
		shell.queue_free()
		return
	var firing_actor_id: int = actors.actor_id_by_tank_instance_id[tank_instance_id]
	var shot_id: int = next_shell_shot_id
	next_shell_shot_id += 1
	var shell_instance_id: int = shell.get_instance_id()
	shot_id_by_shell_instance_id[shell_instance_id] = shot_id
	firing_actor_id_by_shell_instance_id[shell_instance_id] = firing_actor_id
	Utils.connect_checked(shell.impact_resolved, _on_shell_impact_resolved)
	Utils.connect_checked(
		shell.tree_exiting, func() -> void: _on_server_shell_exited(shell_instance_id)
	)
	actors.arena_level.add_child(shell)
	var shell_id: String = ShellManager.get_shell_id(shell.shell_spec)
	runtime.network_gameplay.broadcast_arena_shell_spawn(
		shot_id, firing_actor_id, shell_id, shell.global_position, shell.velocity, shell.rotation
	)


func _on_shell_impact_resolved(
	shell: Shell,
	target_tank: Tank,
	result_type: ShellSpec.ImpactResultType,
	damage: int,
	hit_position: Vector2,
	post_impact_velocity: Vector2,
	post_impact_rotation: float,
	continue_simulation: bool
) -> void:
	var shell_instance_id: int = shell.get_instance_id()
	if not shot_id_by_shell_instance_id.has(shell_instance_id):
		return
	var target_tank_instance_id: int = target_tank.get_instance_id()
	if not actors.actor_id_by_tank_instance_id.has(target_tank_instance_id):
		return
	var target_actor_id: int = actors.actor_id_by_tank_instance_id[target_tank_instance_id]
	var shot_id: int = shot_id_by_shell_instance_id[shell_instance_id]
	var firing_actor_id: int = firing_actor_id_by_shell_instance_id.get(shell_instance_id, 0)
	var remaining_health: int = target_tank._health
	runtime.network_gameplay.broadcast_arena_shell_impact(
		shot_id,
		firing_actor_id,
		target_actor_id,
		int(result_type),
		damage,
		remaining_health,
		hit_position,
		post_impact_velocity,
		post_impact_rotation,
		continue_simulation
	)
	if remaining_health > 0 or damage <= 0:
		return
	var kill_event_seq: int = next_kill_event_seq
	next_kill_event_seq += 1
	runtime.network_gameplay.broadcast_arena_kill_event(
		kill_event_seq,
		firing_actor_id,
		actors.get_actor_player_name(firing_actor_id),
		actors.get_actor_tank_display_name(firing_actor_id),
		shell.shell_spec.shell_name,
		target_actor_id,
		actors.get_actor_player_name(target_actor_id),
		actors.get_actor_tank_display_name(target_actor_id)
	)


func _on_server_shell_exited(shell_instance_id: int) -> void:
	shot_id_by_shell_instance_id.erase(shell_instance_id)
	firing_actor_id_by_shell_instance_id.erase(shell_instance_id)
