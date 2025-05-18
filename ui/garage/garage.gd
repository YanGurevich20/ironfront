class_name Garage extends Control

@onready var header_panel: HeaderPanel = %HeaderPanel
@onready var upgrade_panel: UpgradePanel = %UpgradePanel

signal garage_menu_pressed
signal level_pressed(level: int)

# Callables for level management
var fetch_levels_callable: Callable
var fetch_level_stars_callable: Callable

func _ready() -> void:
	header_panel.display_player_data()
	header_panel.garage_menu_pressed.connect(func()->void: garage_menu_pressed.emit())
	
func refresh_level_buttons() -> void:
	if fetch_levels_callable.is_valid() and fetch_level_stars_callable.is_valid():
		var levels: Dictionary[int, PackedScene] = fetch_levels_callable.call()
		var stars: Dictionary[int, int] = fetch_level_stars_callable.call()
		# Implementation will depend on how the level buttons are displayed in the garage UI
		# This is a placeholder for the actual implementation
		print("Refreshing level buttons with levels: ", levels, " and stars: ", stars)
