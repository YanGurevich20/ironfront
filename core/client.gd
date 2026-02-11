class_name Client
extends Node2D

const OnlineArenaSyncRuntimeScript := preload("res://core/online_arena_sync_runtime.gd")
const ClientMatchResultsData := preload("res://core/client_match_results.gd")
const ShellScene: PackedScene = preload("res://entities/shell/shell.tscn")

var current_level: BaseLevel
var current_level_key: int = 0
var online_arena_level: ArenaLevelMvp
var online_player_tank: Tank
var is_online_arena_active: bool = false

var online_arena_scene: PackedScene = preload("res://levels/arena/arena_level_mvp.tscn")
var shell_spec_cache_by_path: Dictionary[String, ShellSpec] = {}
var active_online_shells_by_shot_id: Dictionary[int, Shell] = {}

@onready var root: SceneTree = get_tree()
@onready var ui_manager: UIManager = %UIManager
@onready var level_container: Node2D = %LevelContainer
@onready var network_client: NetworkClient = %Network
@onready var online_sync_runtime: Object = OnlineArenaSyncRuntimeScript.new()


func _ready() -> void:
	add_child(online_sync_runtime as Node)
	ui_manager.set_network_client(network_client)
	Utils.connect_checked(UiBus.quit_pressed, func() -> void: get_tree().quit())
	Utils.connect_checked(UiBus.play_online_pressed, _connect_to_online_server)
	Utils.connect_checked(UiBus.level_pressed, _start_level)
	Utils.connect_checked(UiBus.pause_input, _pause_game)
	Utils.connect_checked(UiBus.resume_requested, _resume_game)
	Utils.connect_checked(UiBus.restart_level_requested, _restart_level)
	Utils.connect_checked(UiBus.abort_level_requested, _abort_level)
	Utils.connect_checked(UiBus.online_match_abort_requested, _abort_online_match)
	Utils.connect_checked(UiBus.return_to_menu_requested, _quit_level)
	Utils.connect_checked(network_client.join_status_changed, ui_manager.update_online_join_overlay)
	Utils.connect_checked(network_client.join_arena_completed, _on_join_arena_completed)
	Utils.connect_checked(
		network_client.state_snapshot_received,
		func(server_tick: int, player_states: Array) -> void:
			online_sync_runtime.call("on_state_snapshot_received", server_tick, player_states)
	)
	Utils.connect_checked(network_client.arena_shell_spawn_received, _on_arena_shell_spawn_received)
	Utils.connect_checked(
		network_client.arena_shell_impact_received, _on_arena_shell_impact_received
	)
	Utils.connect_checked(GameplayBus.shell_fired, _on_shell_fired)
	Utils.connect_checked(MultiplayerBus.online_join_retry_requested, _connect_to_online_server)
	Utils.connect_checked(
		MultiplayerBus.online_join_cancel_requested,
		func() -> void: network_client.cancel_join_request()
	)
	_save_player_metrics()


func _connect_to_online_server() -> void:
	ui_manager.show_online_join_overlay()
	network_client.connect_to_server()


func _on_join_arena_completed(success: bool, message: String) -> void:
	if not success:
		ui_manager.complete_online_join_overlay(false, message)
		return
	var bootstrap_success: bool = _start_online_arena()
	if not bootstrap_success:
		ui_manager.complete_online_join_overlay(false, "ARENA BOOTSTRAP FAILED")
		return
	ui_manager.hide_online_join_overlay()


func _log_prefix() -> String:
	var peer_id: int = 0
	if multiplayer.multiplayer_peer != null:
		peer_id = multiplayer.get_unique_id()
	return "[client pid=%d peer=%d]" % [OS.get_process_id(), peer_id]


#region level lifecycle
func _pause_game() -> void:
	if is_online_arena_active:
		return
	if current_level == null:
		return
	current_level.evaluate_metrics_and_objectives(false)
	# TODO: Consider moving objective getter to the base level class
	var current_objectives := current_level.objective_manager.objectives
	ui_manager.update_objectives(current_objectives)
	root.set_pause(true)


func _resume_game() -> void:
	root.set_pause(false)


func _start_level(level_key: int) -> void:
	if is_online_arena_active:
		_quit_online_arena()
	ui_manager.set_online_session_active(false)
	_resume_game()
	current_level_key = level_key
	current_level = LevelManager.LEVEL_SCENES[level_key].instantiate()
	Utils.connect_checked(current_level.level_finished, _finish_level)
	Utils.connect_checked(current_level.objectives_updated, ui_manager.update_objectives)
	level_container.add_child(current_level)
	current_level.start_level()
	GameplayBus.level_started.emit()


func _restart_level() -> void:
	if is_online_arena_active:
		push_warning("%s restart_level_ignored_online_arena_active" % _log_prefix())
		return
	_quit_level()
	_start_level(current_level_key)


func _abort_level() -> void:
	if is_online_arena_active:
		push_warning("%s abort_level_ignored_online_arena_active" % _log_prefix())
		return
	if current_level:
		current_level.finish_level(false)


func _abort_online_match() -> void:
	if not is_online_arena_active:
		return
	_quit_online_arena()
	ui_manager.finish_level()
	ui_manager.display_online_match_end("MATCH ABORTED")


func _finish_level(success: bool, metrics: Dictionary, objectives: Array) -> void:
	var reward_info: Dictionary = ClientMatchResultsData.calculate_level_reward(
		metrics, current_level_key
	)
	ui_manager.display_result(success, metrics, objectives, reward_info)
	ui_manager.finish_level()
	_save_player_metrics(metrics)
	_save_game_progress(metrics, current_level_key, int(reward_info.get("total_reward", 0)))


func _quit_level() -> void:
	if is_online_arena_active:
		_quit_online_arena()
		return
	if current_level:
		current_level.level_finished.disconnect(_finish_level)
		current_level.objectives_updated.disconnect(ui_manager.update_objectives)
		level_container.remove_child(current_level)
		current_level.queue_free()
		current_level = null


func _start_online_arena() -> bool:
	if online_arena_scene == null:
		push_error("%s online_arena_scene is null" % _log_prefix())
		return false
	if current_level != null:
		_quit_level()
	if online_arena_level != null:
		_quit_online_arena()
	var arena_level_node: Node = online_arena_scene.instantiate()
	var arena_level_candidate: ArenaLevelMvp = arena_level_node as ArenaLevelMvp
	if arena_level_candidate == null:
		push_error("%s arena scene root must use ArenaLevelMvp script" % _log_prefix())
		arena_level_node.queue_free()
		return false
	level_container.add_child(arena_level_candidate)
	online_arena_level = arena_level_candidate
	var player_tank: Tank = _create_local_player_tank()
	if player_tank == null:
		_quit_online_arena()
		return false
	online_arena_level.add_child(player_tank)
	player_tank.apply_spawn_state(
		network_client.assigned_spawn_position, network_client.assigned_spawn_rotation
	)
	online_player_tank = player_tank
	is_online_arena_active = true
	ui_manager.set_online_session_active(true)
	active_online_shells_by_shot_id.clear()
	online_sync_runtime.call("start_runtime", online_arena_level, online_player_tank)
	network_client.set_arena_input_enabled(true)
	_resume_game()
	GameplayBus.level_started.emit()
	print(
		(
			"%s online_arena_started spawn_position=%s spawn_rotation=%.4f"
			% [
				_log_prefix(),
				network_client.assigned_spawn_position,
				network_client.assigned_spawn_rotation
			]
		)
	)
	return true


func _quit_online_arena() -> void:
	active_online_shells_by_shot_id.clear()
	ui_manager.set_online_session_active(false)
	online_sync_runtime.call("stop_runtime")
	if online_player_tank != null:
		online_player_tank.queue_free()
		online_player_tank = null
	if online_arena_level != null:
		level_container.remove_child(online_arena_level)
		online_arena_level.queue_free()
		online_arena_level = null
	is_online_arena_active = false
	network_client.set_arena_input_enabled(false)


func _create_local_player_tank() -> Tank:
	var player_data: PlayerData = PlayerData.get_instance()
	var selected_tank_id: TankManager.TankId = player_data.selected_tank_id
	var unlocked_tank_ids: Array[TankManager.TankId] = player_data.get_unlocked_tank_ids()
	if not unlocked_tank_ids.has(selected_tank_id):
		if unlocked_tank_ids.size() > 0:
			selected_tank_id = unlocked_tank_ids[0]
		else:
			selected_tank_id = TankManager.TankId.TIGER_1
	return TankManager.create_tank(selected_tank_id, TankManager.TankControllerType.PLAYER)


func _on_shell_fired(shell: Shell, tank: Tank) -> void:
	if not is_online_arena_active or online_arena_level == null or tank != online_player_tank:
		return
	shell.queue_free()


func _on_arena_shell_spawn_received(
	shot_id: int,
	firing_peer_id: int,
	shell_spec_path: String,
	spawn_position: Vector2,
	shell_velocity: Vector2,
	shell_rotation: float
) -> void:
	if not is_online_arena_active:
		return
	if online_arena_level == null:
		return
	if firing_peer_id != multiplayer.get_unique_id():
		online_sync_runtime.call("play_remote_fire_effect", firing_peer_id)
	if shell_spec_path.is_empty():
		push_warning(
			(
				"%s authoritative_shell_spawn_ignored_empty_spec shot_id=%d firing_peer=%d"
				% [_log_prefix(), shot_id, firing_peer_id]
			)
		)
		return
	var shell_spec: ShellSpec = _get_cached_shell_spec(shell_spec_path)
	if shell_spec == null:
		push_warning(
			(
				"%s authoritative_shell_spawn_ignored_invalid_spec shot_id=%d spec=%s"
				% [_log_prefix(), shot_id, shell_spec_path]
			)
		)
		return
	var shell: Shell = ShellScene.instantiate()
	shell.initialize_from_spawn(
		shell_spec, spawn_position, shell_velocity, shell_rotation, null, true
	)
	if active_online_shells_by_shot_id.has(shot_id):
		var existing_shell: Shell = active_online_shells_by_shot_id[shot_id]
		if existing_shell != null:
			existing_shell.queue_free()
	active_online_shells_by_shot_id[shot_id] = shell
	Utils.connect_checked(
		shell.tree_exiting,
		func() -> void:
			var tracked_shell: Shell = active_online_shells_by_shot_id.get(shot_id)
			if tracked_shell == shell:
				active_online_shells_by_shot_id.erase(shot_id)
	)
	online_arena_level.add_child(shell)


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
	if not is_online_arena_active:
		return
	_reconcile_authoritative_shell_impact(
		shot_id, hit_position, post_impact_velocity, post_impact_rotation, continue_simulation
	)
	var target_tank: Tank = online_sync_runtime.call("get_tank_by_peer_id", target_peer_id)
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
	var target_max_health: int = target_tank.tank_spec.health
	var expected_pre_hit_health: int = clamp(remaining_health + damage, 0, target_max_health)
	target_tank.set_health(expected_pre_hit_health)
	var impact_result: ShellSpec.ImpactResult = ShellSpec.ImpactResult.new(damage, result_type)
	target_tank.handle_impact_result(impact_result)
	if target_tank._health != remaining_health:
		target_tank.set_health(remaining_health)


func _reconcile_authoritative_shell_impact(
	shot_id: int,
	hit_position: Vector2,
	post_impact_velocity: Vector2,
	post_impact_rotation: float,
	continue_simulation: bool
) -> void:
	if not active_online_shells_by_shot_id.has(shot_id):
		return
	var impacted_shell: Shell = active_online_shells_by_shot_id[shot_id]
	if impacted_shell == null:
		active_online_shells_by_shot_id.erase(shot_id)
		return
	impacted_shell.global_position = hit_position
	if continue_simulation:
		impacted_shell.starting_global_position = hit_position
		impacted_shell.velocity = post_impact_velocity
		impacted_shell.rotation = post_impact_rotation
		return
	active_online_shells_by_shot_id.erase(shot_id)
	impacted_shell.queue_free()


func _get_cached_shell_spec(shell_spec_path: String) -> ShellSpec:
	if shell_spec_cache_by_path.has(shell_spec_path):
		return shell_spec_cache_by_path[shell_spec_path]
	var loaded_shell_spec_resource: Resource = load(shell_spec_path)
	var loaded_shell_spec: ShellSpec = loaded_shell_spec_resource as ShellSpec
	if loaded_shell_spec == null:
		return null
	shell_spec_cache_by_path[shell_spec_path] = loaded_shell_spec
	return loaded_shell_spec


#endregion
#region data api
func fetch_level_stars(level: int) -> int:
	var game_progress := PlayerData.get_instance()
	return game_progress.get_stars_for_level(level)


#endregion
#region data saves
func _save_player_metrics(new_metrics: Dictionary = {}) -> void:
	var player_metrics: Metrics = Metrics.get_instance()
	player_metrics.merge_metrics(new_metrics)
	player_metrics.save()


func _save_game_progress(new_metrics: Dictionary, level_key: int, dollar_reward: int = 0) -> void:
	var current_run_stars: int = new_metrics.get(Metrics.Metric.STARS_EARNED, 0)
	var game_progress := PlayerData.get_instance()
	var dollars_to_award_this_run: int = dollar_reward

	game_progress.update_progress(level_key, current_run_stars, dollars_to_award_this_run)
	game_progress.save()
	GameplayBus.level_finished_and_saved.emit()

#endregion
