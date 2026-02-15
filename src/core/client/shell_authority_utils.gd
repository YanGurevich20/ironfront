class_name ShellAuthorityUtils
extends RefCounted

const ShellScene: PackedScene = preload("res://src/entities/shell/shell.tscn")
static var shell_spec_cache_by_path: Dictionary[String, ShellSpec] = {}


static func handle_shell_spawn_received(
	client: Client,
	shot_id: int,
	firing_peer_id: int,
	shell_spec_path: String,
	spawn_position: Vector2,
	shell_velocity: Vector2,
	shell_rotation: float
) -> void:
	if not client.is_arena_active or client.arena_level == null:
		return
	if firing_peer_id != client.multiplayer.get_unique_id():
		client.arena_sync_runtime.play_remote_fire_effect(firing_peer_id)
	if shell_spec_path.is_empty():
		push_warning(
			(
				"%s authoritative_shell_spawn_ignored_empty_spec shot_id=%d firing_peer=%d"
				% [client._log_prefix(), shot_id, firing_peer_id]
			)
		)
		return
	var shell_spec: ShellSpec = _get_cached_shell_spec(shell_spec_path)
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
	if client.active_shells_by_shot_id.has(shot_id):
		var existing_shell: Shell = client.active_shells_by_shot_id[shot_id]
		if existing_shell != null:
			existing_shell.queue_free()
	client.active_shells_by_shot_id[shot_id] = shell
	Utils.connect_checked(
		shell.tree_exiting,
		func() -> void:
			var tracked_shell: Shell = client.active_shells_by_shot_id.get(shot_id)
			if tracked_shell == shell:
				client.active_shells_by_shot_id.erase(shot_id)
	)
	client.arena_level.add_child(shell)


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
	if not client.is_arena_active:
		return
	var target_tank: Tank = client.arena_sync_runtime.get_tank_by_peer_id(target_peer_id)
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
	_emit_local_player_impact_event(
		client, shot_id, firing_peer_id, target_peer_id, result_type, damage, target_tank
	)
	_reconcile_authoritative_shell_impact(
		client,
		shot_id,
		hit_position,
		post_impact_velocity,
		post_impact_rotation,
		continue_simulation
	)
	var target_max_health: int = target_tank.tank_spec.health
	var expected_pre_hit_health: int = clamp(remaining_health + damage, 0, target_max_health)
	target_tank.set_health(expected_pre_hit_health)
	var impact_result: ShellSpec.ImpactResult = ShellSpec.ImpactResult.new(damage, result_type)
	target_tank.handle_impact_result(impact_result)
	if target_tank._health != remaining_health:
		target_tank.set_health(remaining_health)


static func handle_loadout_state_received(
	client: Client,
	selected_shell_path: String,
	shell_counts_by_path: Dictionary,
	reload_time_left: float
) -> void:
	if not client.is_arena_active:
		return
	if client.player_tank == null:
		return
	if selected_shell_path.is_empty():
		client.player_tank.set_remaining_shell_count(0)
		GameplayBus.online_loadout_state_updated.emit(
			selected_shell_path, shell_counts_by_path, reload_time_left
		)
		return
	var selected_shell_spec: ShellSpec = _get_cached_shell_spec(selected_shell_path)
	if selected_shell_spec == null:
		push_warning(
			(
				"%s authoritative_loadout_state_invalid_selected_shell path=%s"
				% [client._log_prefix(), selected_shell_path]
			)
		)
		GameplayBus.online_loadout_state_updated.emit(
			selected_shell_path, shell_counts_by_path, reload_time_left
		)
		return
	var selected_shell_count: int = max(0, int(shell_counts_by_path.get(selected_shell_path, 0)))
	client.player_tank.apply_authoritative_shell_state(
		selected_shell_spec, selected_shell_count, reload_time_left
	)
	GameplayBus.online_loadout_state_updated.emit(
		selected_shell_path, shell_counts_by_path, reload_time_left
	)


static func _reconcile_authoritative_shell_impact(
	client: Client,
	shot_id: int,
	hit_position: Vector2,
	post_impact_velocity: Vector2,
	post_impact_rotation: float,
	continue_simulation: bool
) -> void:
	if not client.active_shells_by_shot_id.has(shot_id):
		return
	var impacted_shell: Shell = client.active_shells_by_shot_id[shot_id]
	if impacted_shell == null:
		client.active_shells_by_shot_id.erase(shot_id)
		return
	impacted_shell.global_position = hit_position
	if continue_simulation:
		impacted_shell.starting_global_position = hit_position
		impacted_shell.velocity = post_impact_velocity
		impacted_shell.rotation = post_impact_rotation
		return
	client.active_shells_by_shot_id.erase(shot_id)
	impacted_shell.queue_free()


static func _emit_local_player_impact_event(
	client: Client,
	shot_id: int,
	firing_peer_id: int,
	target_peer_id: int,
	result_type: int,
	damage: int,
	target_tank: Tank
) -> void:
	if client.multiplayer.multiplayer_peer == null:
		return
	var local_peer_id: int = client.multiplayer.get_unique_id()
	var local_is_firing: bool = firing_peer_id == local_peer_id
	var local_is_target: bool = target_peer_id == local_peer_id
	if not local_is_firing and not local_is_target:
		return
	var related_tank_name: String = _resolve_related_tank_name(
		client, local_is_firing, firing_peer_id, target_tank
	)
	var shell_short_name: String = _resolve_shell_type_label(client, shot_id)
	var event_data: Dictionary = _build_local_impact_event_data(
		local_is_target, result_type, damage, related_tank_name, shell_short_name
	)
	GameplayBus.online_player_impact_event.emit(event_data)


static func _resolve_related_tank_name(
	client: Client, local_is_firing: bool, firing_peer_id: int, target_tank: Tank
) -> String:
	if local_is_firing:
		return _resolve_tank_name(target_tank)
	var source_tank: Tank = client.arena_sync_runtime.get_tank_by_peer_id(firing_peer_id)
	return _resolve_tank_name(source_tank)


static func _resolve_tank_name(tank: Tank) -> String:
	if tank == null or tank.tank_spec == null:
		return "TANK"
	var display_name: String = tank.tank_spec.display_name.strip_edges()
	if display_name.is_empty():
		return "TANK"
	return display_name


static func _resolve_shell_type_label(client: Client, shot_id: int) -> String:
	var tracked_shell: Shell = client.active_shells_by_shot_id.get(shot_id)
	if (
		tracked_shell == null
		or tracked_shell.shell_spec == null
		or tracked_shell.shell_spec.base_shell_type == null
	):
		return "SHELL"
	var shell_type_name: String = (
		str(BaseShellType.ShellType.find_key(tracked_shell.shell_spec.base_shell_type.shell_type))
		. strip_edges()
	)
	if shell_type_name.is_empty():
		return "SHELL"
	return shell_type_name


static func _build_local_impact_event_data(
	local_is_target: bool,
	result_type: int,
	damage: int,
	tank_name: String,
	shell_short_name: String
) -> Dictionary:
	var is_non_pen_result: bool = (
		result_type == ShellSpec.ImpactResultType.BOUNCED
		or result_type == ShellSpec.ImpactResultType.UNPENETRATED
		or result_type == ShellSpec.ImpactResultType.SHATTERED
	)
	var safe_damage: int = max(0, damage)
	var hp_prefix: String = "-" if local_is_target else ""
	var hp_text: String = "%s%dHP" % [hp_prefix, safe_damage]
	var hp_color: Color = _resolve_local_impact_event_hp_color(local_is_target, result_type)
	if is_non_pen_result:
		var result_name: String = _resolve_result_name(result_type)
		return {
			"hp_text": hp_text,
			"hp_color": hp_color,
			"verb_text": " %s " % result_name,
			"enemy_text": "[%s]" % tank_name,
			"shell_text": shell_short_name,
		}
	return {
		"hp_text": hp_text,
		"hp_color": hp_color,
		"verb_text": " " if local_is_target else " to ",
		"enemy_text": "[%s]" % tank_name,
		"shell_text": shell_short_name,
	}


static func _resolve_local_impact_event_hp_color(local_is_target: bool, result_type: int) -> Color:
	var is_non_pen_result: bool = (
		result_type == ShellSpec.ImpactResultType.BOUNCED
		or result_type == ShellSpec.ImpactResultType.UNPENETRATED
		or result_type == ShellSpec.ImpactResultType.SHATTERED
	)
	if is_non_pen_result:
		return Colors.GOLD_DARK
	return Colors.ENEMY_RED if local_is_target else Colors.GOLD


static func _resolve_result_name(result_type: int) -> String:
	var result_name: String = str(ShellSpec.ImpactResultType.find_key(result_type)).to_lower()
	if result_name == "unpenetrated":
		return "unpenned"
	if result_name.is_empty():
		return "impact"
	return result_name


static func _get_cached_shell_spec(shell_spec_path: String) -> ShellSpec:
	if shell_spec_cache_by_path.has(shell_spec_path):
		return shell_spec_cache_by_path[shell_spec_path]
	var loaded_shell_spec_resource: Resource = load(shell_spec_path)
	var loaded_shell_spec: ShellSpec = loaded_shell_spec_resource as ShellSpec
	if loaded_shell_spec == null:
		return null
	shell_spec_cache_by_path[shell_spec_path] = loaded_shell_spec
	return loaded_shell_spec
