#TODO: Consider converting to BaseOverlay class (and rename to base_menu)
class_name MainMenu extends Control

@export var fetch_metrics_callable: Callable
@export var fetch_levels_callable: Callable
@export var fetch_level_stars_callable: Callable

@onready var main_menu_box: VBoxContainer = $%MainMenuBox
@onready var play_button: Button = $%PlayButton
@onready var settings_button: Button = $%SettingsButton
@onready var metrics_button: Button = $%MetricsButton
@onready var quit_button: Button = $%QuitButton

@onready var LevelButtonScene := preload("res://ui/main_menu/components/level_button/level_button.tscn")
@onready var KeyValueLabelScene := preload("res://ui/components/key_value_label/key_value_label.tscn")
@onready var level_select_box: VBoxContainer = $%LevelSelectBox
@onready var level_list := $%LevelList
@onready var level_select_back_button: Button = $%BackButton

signal settings_pressed
signal quit_game_pressed
signal level_pressed(level:int)
signal metrics_pressed

func _ready() -> void:
	_show_only([main_menu_box])
	play_button.pressed.connect(_on_play_pressed)
	settings_button.pressed.connect(func()->void:settings_pressed.emit())
	metrics_button.pressed.connect(func()->void:metrics_pressed.emit())
	quit_button.pressed.connect(func()->void:quit_game_pressed.emit())
	level_select_back_button.pressed.connect(func()->void:_show_only([main_menu_box]))

func _on_play_pressed()->void:
	_show_only([level_select_box])
	refresh_level_buttons()

func refresh_level_buttons() -> void:
	for child in level_list.get_children():
		level_list.remove_child(child)
		child.queue_free()
	if not fetch_levels_callable:
		push_error("fetch levels not defined!", fetch_levels_callable)
		return
	var levels: Dictionary = fetch_levels_callable.call()
	var is_next_locked := false
	for level_number:int in levels:
		var level_button :LevelButton= LevelButtonScene.instantiate()
		var level_stars :int= fetch_level_stars_callable.call(level_number)
		level_button.disabled = is_next_locked
		level_button.level = level_number
		level_button.stars = level_stars
		level_button.level_pressed.connect(func(level: int)->void:level_pressed.emit(level))
		is_next_locked = level_stars < 2 #TODO: Consider variable condition for level pass
		level_list.add_child(level_button)

func _show_only(visible_nodes: Array[Node]) -> void:
	var control_nodes: Array[Node] = [main_menu_box, level_select_box]
	for node in control_nodes:
		node.visible = node in visible_nodes
