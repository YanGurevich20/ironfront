class_name DeveloperMenu extends Control

@onready var custom_func_button: Button = %CustomFuncButton
@onready var add_dollars_button: Button = %AddDollarsButton
@onready var delete_game_progress_button: Button = %DeletePlayerDataButton
@onready var delete_metrics_button: Button = %DeleteMetricsButton
@onready var quit_button: Button = %QuitButton

func _ready() -> void:
	custom_func_button.pressed.connect(func()->void: _custom_func())
	add_dollars_button.pressed.connect(func()->void: _add_dollars())
	delete_game_progress_button.pressed.connect(func()->void: _delete_game_progress())
	delete_metrics_button.pressed.connect(func()->void: _delete_metrics())
	quit_button.pressed.connect(func()->void: get_tree().quit())

func _custom_func() -> void:
	pass
	
func _add_dollars() -> void:
	var player_data := PlayerData.get_instance()
	player_data.add_dollars(500000)
	player_data.save()

func _delete_game_progress() -> void:
	LoadableData.reset(PlayerData)

func _delete_metrics() -> void:
	LoadableData.reset(Metrics)

