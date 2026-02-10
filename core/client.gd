class_name Client
extends Node2D

# === Variables ===
var current_level: BaseLevel
var current_level_key: int = 0

# === Onready Variables ===
@onready var root: SceneTree = get_tree()
@onready var ui_manager: UIManager = %UIManager
@onready var level_container: Node2D = %LevelContainer
@onready var network_client: NetworkClient = %Network


# === Built-in Methods ===
func _ready() -> void:
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
	Utils.connect_checked(MultiplayerBus.online_join_retry_requested, _connect_to_online_server)
	Utils.connect_checked(
		MultiplayerBus.online_join_cancel_requested, _on_online_join_cancel_requested
	)
	_save_player_metrics()


func _connect_to_online_server() -> void:
	print(
		"%s[ui] play_online_pressed -> show_online_join_overlay + connect_to_server" % _log_prefix()
	)
	ui_manager.show_online_join_overlay()
	network_client.connect_to_server()


func _on_join_status_changed(message: String, is_error: bool) -> void:
	print("%s[ui] join_status_changed is_error=%s message=%s" % [_log_prefix(), is_error, message])
	ui_manager.update_online_join_overlay(message, is_error)


func _on_join_arena_completed(success: bool, message: String) -> void:
	print("%s[ui] join_arena_completed success=%s message=%s" % [_log_prefix(), success, message])
	ui_manager.complete_online_join_overlay(success, message)


func _on_online_join_cancel_requested() -> void:
	print("%s[ui] online_join_cancel_requested -> cancel_join_request" % _log_prefix())
	network_client.cancel_join_request()


func _log_prefix() -> String:
	var peer_id: int = 0
	if multiplayer.multiplayer_peer != null:
		peer_id = multiplayer.get_unique_id()
	return "[client pid=%d peer=%d]" % [OS.get_process_id(), peer_id]


#region level lifecycle
func _pause_game() -> void:
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
	_resume_game()
	current_level_key = level_key
	current_level = LevelManager.LEVEL_SCENES[level_key].instantiate()
	Utils.connect_checked(current_level.level_finished, _finish_level)
	Utils.connect_checked(current_level.objectives_updated, _on_objectives_updated)
	level_container.add_child(current_level)
	current_level.start_level()
	GameplayBus.level_started.emit()


func _restart_level() -> void:
	_quit_level()
	_start_level(current_level_key)


func _abort_level() -> void:
	if current_level:
		current_level.finish_level(false)


func _finish_level(success: bool, metrics: Dictionary, objectives: Array) -> void:
	var reward_info: Dictionary = calculate_level_reward(metrics, current_level_key)
	ui_manager.display_result(success, metrics, objectives, reward_info)
	ui_manager.finish_level()
	_save_player_metrics(metrics)
	_save_game_progress(metrics, current_level_key, int(reward_info.get("total_reward", 0)))


func _quit_level() -> void:
	if current_level:
		current_level.level_finished.disconnect(_finish_level)
		current_level.objectives_updated.disconnect(_on_objectives_updated)
		level_container.remove_child(current_level)
		current_level.queue_free()
		current_level = null


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
