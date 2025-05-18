class_name DeveloperMenu extends Control

@onready var custom_func_button: Button = %CustomFuncButton
@onready var delete_game_progress_button: Button = %DeleteGameProgressButton
@onready var print_game_progress_button: Button = %PrintGameProgressButton
@onready var delete_metrics_button: Button = %DeleteMetricsButton
@onready var print_metrics_button: Button = %PrintMetricsButton
@onready var quit_button: Button = %QuitButton

func _ready() -> void:
	custom_func_button.pressed.connect(func()->void: _custom_func())
	delete_game_progress_button.pressed.connect(func()->void: _delete_game_progress())
	print_game_progress_button.pressed.connect(func()->void: _print_game_progress())
	delete_metrics_button.pressed.connect(func()->void: _delete_metrics())
	print_metrics_button.pressed.connect(func()->void: _print_metrics())
	quit_button.pressed.connect(func()->void: get_tree().quit())

func _custom_func() -> void:
	LoadableData.get_instance(GameProgress).update_progress(1, 1, 100)

func _delete_game_progress() -> void:
	LoadableData.reset(GameProgress)
	print("game progress deleted")

func _print_game_progress() -> void:
	LoadableData.get_instance(GameProgress).print_properties()

func _delete_metrics() -> void:
	LoadableData.reset(Metrics)
	print("metrics deleted")

func _print_metrics() -> void:
	LoadableData.get_instance(Metrics).print_properties()
