class_name OfflineRuntime
extends Node

signal objectives_updated(objectives: Array)
signal level_completed(
	success: bool, metrics: Dictionary, objectives: Array, reward_info: Dictionary
)

var current_level: BaseLevel
var current_level_key: int = 0

@onready var level_container: Node2D = %LevelContainer


func is_active() -> bool:
	return current_level != null


func start_level(level_key: int) -> void:
	resume_level()
	current_level_key = level_key
	if current_level != null:
		_quit_current_level()
	var level_node: Node = LevelManager.LEVEL_SCENES[level_key].instantiate()
	var next_level: BaseLevel = level_node as BaseLevel
	assert(next_level != null, "Level scene must instantiate BaseLevel")
	current_level = next_level
	Utils.connect_checked(current_level.level_finished, _on_level_finished)
	Utils.connect_checked(current_level.objectives_updated, _on_objectives_updated)
	level_container.add_child(current_level)
	current_level.start_level()
	GameplayBus.level_started.emit()


func pause_level() -> void:
	if current_level == null:
		return
	current_level.evaluate_metrics_and_objectives(false)
	get_tree().set_pause(true)


func resume_level() -> void:
	get_tree().set_pause(false)


func restart_level() -> void:
	if current_level == null:
		return
	_quit_current_level()
	start_level(current_level_key)


func abort_level() -> void:
	if current_level == null:
		return
	current_level.finish_level(false)


func quit_level() -> void:
	if current_level == null:
		return
	_quit_current_level()


func _on_objectives_updated(objectives: Array) -> void:
	objectives_updated.emit(objectives)


func _on_level_finished(success: bool, metrics: Dictionary, objectives: Array) -> void:
	var reward_info: Dictionary = MatchResults.calculate_level_reward(metrics, current_level_key)
	PlayerProfileUtils.save_player_metrics(metrics)
	PlayerProfileUtils.save_game_progress(
		metrics, current_level_key, int(reward_info.get("total_reward", 0))
	)
	level_completed.emit(success, metrics, objectives, reward_info)


func _quit_current_level() -> void:
	if current_level == null:
		return
	if current_level.level_finished.is_connected(_on_level_finished):
		current_level.level_finished.disconnect(_on_level_finished)
	if current_level.objectives_updated.is_connected(_on_objectives_updated):
		current_level.objectives_updated.disconnect(_on_objectives_updated)
	level_container.remove_child(current_level)
	current_level.queue_free()
	current_level = null
