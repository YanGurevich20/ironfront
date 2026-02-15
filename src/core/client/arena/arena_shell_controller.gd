class_name ArenaClientShellController
extends Node

const ShellScene: PackedScene = preload("res://src/entities/shell/shell.tscn")

var arena_level: ArenaLevelMvp
var local_player_tank: Tank
var active_shells_by_shot_id: Dictionary[int, Shell] = {}
var replication: ArenaReplication
var online_runtime: ClientOnlineRuntime


func configure(
	next_replication: ArenaReplication, next_online_runtime: ClientOnlineRuntime
) -> void:
	replication = next_replication
	online_runtime = next_online_runtime
	Utils.connect_checked(GameplayBus.shell_fired, handle_local_shell_fired)
	Utils.connect_checked(
		GameplayBus.update_remaining_shell_count, _on_update_remaining_shell_count
	)
	Utils.connect_checked(online_runtime.arena_shell_spawn_received, handle_shell_spawn_received)
	Utils.connect_checked(online_runtime.arena_shell_impact_received, handle_shell_impact_received)
	Utils.connect_checked(
		online_runtime.arena_loadout_state_received, handle_loadout_state_received
	)


func start_runtime(next_arena_level: ArenaLevelMvp, next_local_player_tank: Tank) -> void:
	arena_level = next_arena_level
	local_player_tank = next_local_player_tank
	active_shells_by_shot_id.clear()


func stop_runtime() -> void:
	for shell_variant: Variant in active_shells_by_shot_id.values():
		var shell: Shell = shell_variant
		if shell != null:
			shell.queue_free()
	active_shells_by_shot_id.clear()
	arena_level = null
	local_player_tank = null


func replace_local_player_tank(next_local_player_tank: Tank) -> void:
	local_player_tank = next_local_player_tank


func handle_local_shell_fired(shell: Shell, tank: Tank) -> void:
	if arena_level == null or tank != local_player_tank:
		return
	shell.queue_free()


func handle_shell_spawn_received(
	shot_id: int,
	firing_peer_id: int,
	shell_id: String,
	spawn_position: Vector2,
	shell_velocity: Vector2,
	shell_rotation: float
) -> void:
	if arena_level == null:
		return
	if replication != null and firing_peer_id != multiplayer.get_unique_id():
		replication.play_remote_fire_effect(firing_peer_id)
	var shell_spec: ShellSpec = ShellManager.get_shell_spec(shell_id)
	assert(shell_spec != null, "Invalid shell_id from server: %s" % shell_id)
	var shell: Shell = ShellScene.instantiate()
	shell.initialize_from_spawn(
		shell_spec, spawn_position, shell_velocity, shell_rotation, null, true
	)
	if active_shells_by_shot_id.has(shot_id):
		var existing_shell: Shell = active_shells_by_shot_id[shot_id]
		if existing_shell != null:
			existing_shell.queue_free()
	active_shells_by_shot_id[shot_id] = shell
	Utils.connect_checked(
		shell.tree_exiting,
		func() -> void:
			var tracked_shell: Shell = active_shells_by_shot_id.get(shot_id)
			if tracked_shell == shell:
				active_shells_by_shot_id.erase(shot_id)
	)
	arena_level.add_child(shell)


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
	if replication == null:
		return
	var target_tank: Tank = replication.get_tank_by_peer_id(target_peer_id)
	if target_tank == null:
		push_warning(
			(
				(
					"%s authoritative_shell_impact_missing_target shot_id=%d "
					+ "firing_peer=%d target_peer=%d hit_position=%s"
				)
				% [_log_prefix(), shot_id, firing_peer_id, target_peer_id, hit_position]
			)
		)
		return
	_emit_local_player_impact_event(
		shot_id, firing_peer_id, target_peer_id, result_type, damage, target_tank
	)
	_reconcile_authoritative_shell_impact(
		shot_id, hit_position, post_impact_velocity, post_impact_rotation, continue_simulation
	)
	var target_max_health: int = target_tank.tank_spec.health
	var expected_pre_hit_health: int = clamp(remaining_health + damage, 0, target_max_health)
	target_tank.set_health(expected_pre_hit_health)
	var impact_result: ShellSpec.ImpactResult = ShellSpec.ImpactResult.new(damage, result_type)
	target_tank.handle_impact_result(impact_result)
	if target_tank._health != remaining_health:
		target_tank.set_health(remaining_health)


func handle_loadout_state_received(
	selected_shell_id: String, shell_counts_by_id: Dictionary, reload_time_left: float
) -> void:
	if local_player_tank == null:
		return
	var selected_shell_spec: ShellSpec = ShellManager.get_shell_spec(selected_shell_id)
	assert(
		selected_shell_spec != null, "Invalid selected_shell_id from server: %s" % selected_shell_id
	)
	var selected_shell_count: int = max(0, int(shell_counts_by_id.get(selected_shell_id, 0)))
	local_player_tank.apply_authoritative_shell_state(
		selected_shell_spec, selected_shell_count, reload_time_left
	)
	GameplayBus.online_loadout_state_updated.emit(
		selected_shell_id, shell_counts_by_id, reload_time_left
	)


func _reconcile_authoritative_shell_impact(
	shot_id: int,
	hit_position: Vector2,
	post_impact_velocity: Vector2,
	post_impact_rotation: float,
	continue_simulation: bool
) -> void:
	if not active_shells_by_shot_id.has(shot_id):
		return
	var impacted_shell: Shell = active_shells_by_shot_id[shot_id]
	if impacted_shell == null:
		active_shells_by_shot_id.erase(shot_id)
		return
	impacted_shell.global_position = hit_position
	if continue_simulation:
		impacted_shell.starting_global_position = hit_position
		impacted_shell.velocity = post_impact_velocity
		impacted_shell.rotation = post_impact_rotation
		return
	active_shells_by_shot_id.erase(shot_id)
	impacted_shell.queue_free()


func _emit_local_player_impact_event(
	shot_id: int,
	firing_peer_id: int,
	target_peer_id: int,
	result_type: int,
	damage: int,
	target_tank: Tank
) -> void:
	if multiplayer.multiplayer_peer == null:
		return
	var local_peer_id: int = multiplayer.get_unique_id()
	var local_is_firing: bool = firing_peer_id == local_peer_id
	var local_is_target: bool = target_peer_id == local_peer_id
	if not local_is_firing and not local_is_target:
		return
	var related_tank_name: String = _resolve_related_tank_name(
		local_is_firing, firing_peer_id, target_tank
	)
	var shell_short_name: String = _resolve_shell_type_label(shot_id)
	var event_data: Dictionary = _build_local_impact_event_data(
		local_is_target, result_type, damage, related_tank_name, shell_short_name
	)
	GameplayBus.online_player_impact_event.emit(event_data)


func _resolve_related_tank_name(
	local_is_firing: bool, firing_peer_id: int, target_tank: Tank
) -> String:
	if local_is_firing:
		return _resolve_tank_name(target_tank)
	var source_tank: Tank = replication.get_tank_by_peer_id(firing_peer_id)
	return _resolve_tank_name(source_tank)


func _resolve_tank_name(tank: Tank) -> String:
	if tank == null or tank.tank_spec == null:
		return "TANK"
	var display_name: String = tank.tank_spec.display_name.strip_edges()
	if display_name.is_empty():
		return "TANK"
	return display_name


func _resolve_shell_type_label(shot_id: int) -> String:
	var tracked_shell: Shell = active_shells_by_shot_id.get(shot_id)
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


func _build_local_impact_event_data(
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


func _resolve_local_impact_event_hp_color(local_is_target: bool, result_type: int) -> Color:
	var is_non_pen_result: bool = (
		result_type == ShellSpec.ImpactResultType.BOUNCED
		or result_type == ShellSpec.ImpactResultType.UNPENETRATED
		or result_type == ShellSpec.ImpactResultType.SHATTERED
	)
	if is_non_pen_result:
		return Colors.GOLD_DARK
	return Colors.ENEMY_RED if local_is_target else Colors.GOLD


func _on_update_remaining_shell_count(count: int) -> void:
	if local_player_tank == null:
		return
	local_player_tank.set_remaining_shell_count(count)


func _resolve_result_name(result_type: int) -> String:
	var result_name: String = str(ShellSpec.ImpactResultType.find_key(result_type)).to_lower()
	if result_name == "unpenetrated":
		return "unpenned"
	if result_name.is_empty():
		return "impact"
	return result_name


func _log_prefix() -> String:
	var peer_id: int = 0
	if multiplayer.multiplayer_peer != null:
		peer_id = multiplayer.get_unique_id()
	return "[client-shell pid=%d peer=%d]" % [OS.get_process_id(), peer_id]
