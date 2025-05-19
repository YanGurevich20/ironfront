class_name Garage extends Control

@onready var header_panel: HeaderPanel = %HeaderPanel
@onready var upgrade_panel: UpgradePanel = %UpgradePanel
@onready var tank_list_panel: TankListPanel = %TankListPanel
@onready var tank_display_panel: TankDisplayPanel = %TankDisplayPanel

signal garage_menu_pressed
signal level_pressed(level: int)

var fetch_levels_callable: Callable
var fetch_level_stars_callable: Callable

func _ready() -> void:
	header_panel.display_player_data()
	header_panel.garage_menu_pressed.connect(func()->void: garage_menu_pressed.emit())

	var game_progress: PlayerData = LoadableData.get_instance(PlayerData)
	tank_list_panel.set_data(game_progress.dollars, game_progress.unlocked_tank_ids)
	tank_list_panel.unlock_requested.connect(_on_unlock_requested)
	tank_list_panel.tank_selected.connect(_on_tank_selected)

	# Request tank selection update after connections are established
	if tank_list_panel._selected_item != null:
		tank_display_panel.display_tank(tank_list_panel._selected_item.tank_id)

func refresh_level_buttons() -> void:
	if fetch_levels_callable.is_valid() and fetch_level_stars_callable.is_valid():
		var levels: Dictionary[int, PackedScene] = fetch_levels_callable.call()
		var stars: Dictionary[int, int] = fetch_level_stars_callable.call()
		print("Refreshing level buttons with levels: ", levels, " and stars: ", stars)

func _on_unlock_requested(tank_id: TankManager.TankId) -> void:
	var progress: PlayerData = LoadableData.get_instance(PlayerData)
	var tank_spec: TankSpec = TankManager.get_tank_spec(tank_id)
	# Validate funds
	if progress.dollars < tank_spec.dollar_cost:
		return # Not enough funds; may show feedback later.
	# Apply purchase
	progress.dollars -= tank_spec.dollar_cost
	progress.unlocked_tank_ids.append(tank_id)
	progress.save()

	# Update UI
	header_panel.display_player_data()
	tank_list_panel.set_data(progress.dollars, progress.unlocked_tank_ids)
	# Auto-select the newly unlocked tank
	tank_list_panel.select_tank_by_id(tank_id)

func _on_tank_selected(tank_id: TankManager.TankId) -> void:
	tank_display_panel.display_tank(tank_id)
