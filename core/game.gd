class_name Game extends Node2D

# === Variables ===
var current_level: BaseLevel
var current_level_key: int = 0

# === Onready Variables ===
@onready var root: SceneTree = get_tree()
@onready var ui_manager: UIManager= $UIManager
@onready var tank_control: = $UIManager/TankControl
@onready var level_container: = $LevelContainer

# === Built-in Methods ===
func _ready() -> void:
	SignalBus.quit_pressed.connect(func() -> void: get_tree().quit())
	SignalBus.level_pressed.connect(_start_level)
	SignalBus.pause_input.connect(_pause_game)
	ui_manager.resume_game.connect(_resume_game)
	ui_manager.restart_level.connect(_restart_level)
	ui_manager.abort_level.connect(_abort_level)
	ui_manager.return_to_menu.connect(_quit_level)
	_save_player_metrics()

#region level lifecycle
func _pause_game() -> void:
	current_level.evaluate_metrics_and_objectives(false)
	#TODO: Consider moving objective getter to the base level class
	var current_objectives: = current_level.objective_manager.objectives
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
	current_level.level_finished.connect(_finish_level)
	current_level.objectives_updated.connect(_on_objectives_updated)
	level_container.add_child(current_level)
	current_level.start_level()
	SignalBus.level_started.emit()

func _restart_level() -> void:
	if current_level_key != 0:
		_quit_level()
		_start_level(current_level_key)

func _abort_level()-> void:
	if current_level: current_level.finish_level(false)

func _finish_level(success: bool, metrics: Dictionary, objectives: Array) -> void:
	ui_manager.display_result(success, metrics, objectives)
	ui_manager.reset_input()
	_save_player_metrics(metrics)
	_save_game_progress(metrics, current_level_key)

func _quit_level() -> void:
	if current_level:
		current_level.level_finished.disconnect(_finish_level)
		if current_level.is_connected("objectives_updated", _on_objectives_updated):
				current_level.objectives_updated.disconnect(_on_objectives_updated)
		current_level.queue_free()
		current_level = null

#endregion
#region data api

func fetch_level_stars(level: int)->int:
	var game_progress := PlayerData.get_instance()
	return game_progress.get_stars_for_level(level)

#endregion
#region data saves
func _save_player_metrics(new_metrics: Dictionary = {}) -> void:
	var player_metrics: Metrics = Metrics.get_instance()
	player_metrics.merge_metrics(new_metrics)
	player_metrics.save()

func _save_game_progress(new_metrics: Dictionary, level_key: int) -> void:
	var current_run_stars: int = new_metrics.get(Metrics.Metric.STARS_EARNED, 0)
	var game_progress := PlayerData.get_instance()
	var previous_max_stars: int = game_progress.get_stars_for_level(level_key)
	var dollars_to_award_this_run: int = 0

	if current_run_stars > previous_max_stars:
		var star_dollar_values: Dictionary = {
			1: 50_000,
			2: 100_000,
			3: 200_000,
		}

		for star_level_iter in range(previous_max_stars + 1, current_run_stars + 1):
			var dollars_for_this_star: int = star_dollar_values.get(star_level_iter, 0)
			dollars_to_award_this_run += dollars_for_this_star

	game_progress.update_progress(level_key, current_run_stars, dollars_to_award_this_run)
	game_progress.save()
	SignalBus.level_finished_and_saved.emit()
#endregion
