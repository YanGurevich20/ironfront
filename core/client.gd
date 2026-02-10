class_name Client
extends Node2D

# === Variables ===
const OnlineArenaSyncRuntimeScript := preload("res://core/online_arena_sync_runtime.gd")

var current_level: BaseLevel
var current_level_key: int = 0
var online_arena_level: ArenaLevelMvp
var online_player_tank: Tank
var is_online_arena_active: bool = false

var online_arena_scene: PackedScene = preload("res://levels/arena/arena_level_mvp.tscn")

# === Onready Variables ===
@onready var root: SceneTree = get_tree()
@onready var ui_manager: UIManager = %UIManager
@onready var level_container: Node2D = %LevelContainer
@onready var network_client: NetworkClient = %Network
@onready var online_sync_runtime: Object = OnlineArenaSyncRuntimeScript.new()


# === Built-in Methods ===
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
	Utils.connect_checked(UiBus.return_to_menu_requested, _quit_level)
	Utils.connect_checked(network_client.join_status_changed, _on_join_status_changed)
	Utils.connect_checked(network_client.join_arena_completed, _on_join_arena_completed)
	Utils.connect_checked(
		network_client.state_snapshot_received,
		func(server_tick: int, player_states: Array) -> void:
			online_sync_runtime.call("on_state_snapshot_received", server_tick, player_states)
	)
	Utils.connect_checked(GameplayBus.shell_fired, _on_shell_fired)
	Utils.connect_checked(MultiplayerBus.online_join_retry_requested, _connect_to_online_server)
	Utils.connect_checked(
		MultiplayerBus.online_join_cancel_requested, _on_online_join_cancel_requested
	)
	_save_player_metrics()


func _connect_to_online_server() -> void:
	ui_manager.show_online_join_overlay()
	network_client.connect_to_server()


func _on_join_status_changed(message: String, is_error: bool) -> void:
	ui_manager.update_online_join_overlay(message, is_error)


func _on_join_arena_completed(success: bool, message: String) -> void:
	if not success:
		ui_manager.complete_online_join_overlay(false, message)
		return
	var bootstrap_success: bool = _start_online_arena()
	if not bootstrap_success:
		ui_manager.complete_online_join_overlay(false, "ARENA BOOTSTRAP FAILED")
		return
	ui_manager.hide_online_join_overlay()


func _on_online_join_cancel_requested() -> void:
	network_client.cancel_join_request()


func _log_prefix() -> String:
	var peer_id: int = 0
	if multiplayer.multiplayer_peer != null:
		peer_id = multiplayer.get_unique_id()
	return "[client pid=%d peer=%d]" % [OS.get_process_id(), peer_id]


#region level lifecycle
func _pause_game() -> void:
	if is_online_arena_active:
		root.set_pause(true)
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


func quit_game() -> void:
	root.quit()


func _on_objectives_updated(objectives: Array[Objective]) -> void:
	ui_manager.update_objectives(objectives)


func _start_level(level_key: int) -> void:
	if is_online_arena_active:
		_quit_online_arena()
	_resume_game()
	current_level_key = level_key
	current_level = LevelManager.LEVEL_SCENES[level_key].instantiate()
	Utils.connect_checked(current_level.level_finished, _finish_level)
	Utils.connect_checked(current_level.objectives_updated, _on_objectives_updated)
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


func _finish_level(success: bool, metrics: Dictionary, objectives: Array) -> void:
	var reward_info: Dictionary = calculate_level_reward(metrics, current_level_key)
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
		current_level.objectives_updated.disconnect(_on_objectives_updated)
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
	player_tank.global_position = network_client.assigned_spawn_position
	player_tank.global_rotation = network_client.assigned_spawn_rotation
	online_arena_level.add_child(player_tank)
	online_player_tank = player_tank
	is_online_arena_active = true
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
	if not is_online_arena_active:
		return
	if online_arena_level == null:
		return
	if tank != online_player_tank:
		return
	online_arena_level.add_child(shell)


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
#region reward calculation
func calculate_level_reward(new_metrics: Dictionary, level_key: int) -> Dictionary:
	var current_run_stars: int = new_metrics.get(Metrics.Metric.STARS_EARNED, 0)
	var game_progress := PlayerData.get_instance()
	var previous_max_stars: int = game_progress.get_stars_for_level(level_key)
	var dollars_to_award_this_run: int = 0
	var doubled_stars: Array[int] = []

	var star_dollar_values: Dictionary = {
		1: 5_000,
		2: 15_000,
		3: 30_000,
	}

	# Award base rewards for all stars earned in this run
	for star_level in range(1, current_run_stars + 1):
		var base_dollars: int = star_dollar_values.get(star_level, 0)
		var dollars_for_this_star: int = base_dollars

		# Double the reward if this star is being earned for the first time
		if star_level > previous_max_stars:
			dollars_for_this_star = base_dollars * 2
			doubled_stars.append(star_level)

		dollars_to_award_this_run += dollars_for_this_star

	return {"total_reward": dollars_to_award_this_run, "doubled_stars": doubled_stars}
#endregion
