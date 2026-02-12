class_name ClientOnlineShellAuthorityUtils
extends RefCounted

const ShellScene: PackedScene = preload("res://entities/shell/shell.tscn")


static func handle_shell_spawn_received(
	client: Client,
	shot_id: int,
	firing_peer_id: int,
	shell_spec_path: String,
	spawn_position: Vector2,
	shell_velocity: Vector2,
	shell_rotation: float
) -> void:
	if not client.is_online_arena_active or client.online_arena_level == null:
		return
	if firing_peer_id != client.multiplayer.get_unique_id():
		client.online_sync_runtime.call("play_remote_fire_effect", firing_peer_id)
	if shell_spec_path.is_empty():
		push_warning(
			(
				"%s authoritative_shell_spawn_ignored_empty_spec shot_id=%d firing_peer=%d"
				% [client._log_prefix(), shot_id, firing_peer_id]
			)
		)
		return
	var shell_spec: ShellSpec = client._get_cached_shell_spec(shell_spec_path)
	if shell_spec == null:
		push_warning(
			(
				"%s authoritative_shell_spawn_ignored_invalid_spec shot_id=%d spec=%s"
				% [client._log_prefix(), shot_id, shell_spec_path]
			)
		)
		return
	var shell: Shell = ShellScene.instantiate()
	shell.initialize_from_spawn(
		shell_spec, spawn_position, shell_velocity, shell_rotation, null, true
	)
	if client.active_online_shells_by_shot_id.has(shot_id):
		var existing_shell: Shell = client.active_online_shells_by_shot_id[shot_id]
		if existing_shell != null:
			existing_shell.queue_free()
	client.active_online_shells_by_shot_id[shot_id] = shell
	Utils.connect_checked(
		shell.tree_exiting,
		func() -> void:
			var tracked_shell: Shell = client.active_online_shells_by_shot_id.get(shot_id)
			if tracked_shell == shell:
				client.active_online_shells_by_shot_id.erase(shot_id)
	)
	client.online_arena_level.add_child(shell)


static func handle_shell_impact_received(
	client: Client,
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
	if not client.is_online_arena_active:
		return
	_reconcile_authoritative_shell_impact(
		client,
		shot_id,
		hit_position,
		post_impact_velocity,
		post_impact_rotation,
		continue_simulation
	)
	var target_tank: Tank = client.online_sync_runtime.call("get_tank_by_peer_id", target_peer_id)
	if target_tank == null:
		push_warning(
			(
				(
					"%s authoritative_shell_impact_missing_target shot_id=%d "
					+ "firing_peer=%d target_peer=%d hit_position=%s"
				)
				% [client._log_prefix(), shot_id, firing_peer_id, target_peer_id, hit_position]
			)
		)
		return
	var target_max_health: int = target_tank.tank_spec.health
	var expected_pre_hit_health: int = clamp(remaining_health + damage, 0, target_max_health)
	target_tank.set_health(expected_pre_hit_health)
	var impact_result: ShellSpec.ImpactResult = ShellSpec.ImpactResult.new(damage, result_type)
	target_tank.handle_impact_result(impact_result)
	if target_tank._health != remaining_health:
		target_tank.set_health(remaining_health)


static func _reconcile_authoritative_shell_impact(
	client: Client,
	shot_id: int,
	hit_position: Vector2,
	post_impact_velocity: Vector2,
	post_impact_rotation: float,
	continue_simulation: bool
) -> void:
	if not client.active_online_shells_by_shot_id.has(shot_id):
		return
	var impacted_shell: Shell = client.active_online_shells_by_shot_id[shot_id]
	if impacted_shell == null:
		client.active_online_shells_by_shot_id.erase(shot_id)
		return
	impacted_shell.global_position = hit_position
	if continue_simulation:
		impacted_shell.starting_global_position = hit_position
		impacted_shell.velocity = post_impact_velocity
		impacted_shell.rotation = post_impact_rotation
		return
	client.active_online_shells_by_shot_id.erase(shot_id)
	impacted_shell.queue_free()
