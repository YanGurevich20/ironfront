class_name DeveloperMenu extends Control

@onready var custom_func_button: Button = %CustomFuncButton
@onready var add_dollars_button: Button = %AddDollarsButton
@onready var delete_game_progress_button: Button = %DeletePlayerDataButton
@onready var delete_metrics_button: Button = %DeleteMetricsButton
@onready var quit_button: Button = %QuitButton


func _ready() -> void:
	Utils.connect_checked(custom_func_button.pressed, func() -> void: _custom_func())
	Utils.connect_checked(add_dollars_button.pressed, func() -> void: _add_dollars())
	Utils.connect_checked(
		delete_game_progress_button.pressed, func() -> void: _delete_game_progress()
	)
	Utils.connect_checked(delete_metrics_button.pressed, func() -> void: _delete_metrics())
	Utils.connect_checked(quit_button.pressed, func() -> void: get_tree().quit())


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
