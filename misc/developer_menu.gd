class_name DeveloperMenu extends Control

@onready var custom_func_button: Button = %CustomFuncButton
@onready var delete_game_progress_button: Button = %DeletePlayerDataButton
@onready var print_game_progress_button: Button = %PrintPlayerDataButton
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
	# LoadableData.reset(PlayerData)
	var player_data := PlayerData.get_instance()
	player_data.add_dollars(500000)

	# player_data.print_properties()
	player_data.save()

func _delete_game_progress() -> void:
	LoadableData.reset(PlayerData)

func _print_game_progress() -> void:
	PlayerData.get_instance().print_properties()

func _delete_metrics() -> void:
	LoadableData.reset(Metrics)

func _print_metrics() -> void:
	Metrics.get_instance().print_properties()
