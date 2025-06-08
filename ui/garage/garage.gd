class_name Garage extends Control

@onready var header_panel: HeaderPanel = %HeaderPanel
@onready var upgrade_panel: UpgradePanel = %UpgradePanel
@onready var tank_list_panel: TankListPanel = %TankListPanel
@onready var tank_display_panel: TankDisplayPanel = %TankDisplayPanel

var player_data: PlayerData = PlayerData.get_instance()
signal garage_menu_pressed

func _ready() -> void:
	header_panel.garage_menu_pressed.connect(func()->void: garage_menu_pressed.emit())
	tank_list_panel.unlock_tank_requested.connect(_on_tank_unlock_requested)
	tank_list_panel.tank_selected.connect(_on_tank_selected)
	SignalBus.shell_unlock_requested.connect(_on_shell_unlock_requested)
	SignalBus.level_finished_and_saved.connect(display_player_data)
	display_player_data()

func _on_tank_unlock_requested(tank_id: TankManager.TankId) -> void:
	var tank_spec: TankSpec = TankManager.TANK_SPECS[tank_id]
	if player_data.dollars < tank_spec.dollar_cost:
		return #TODO: Feedback insufficient funds
	player_data.dollars -= tank_spec.dollar_cost
	player_data.unlock_tank(tank_id)
	player_data.selected_tank_id = tank_id
	var player_tank_config := player_data.get_tank_config(player_data.selected_tank_id)
	player_tank_config.unlock_shell(TankManager.TANK_SPECS[tank_id].allowed_shells[0])
	player_data.save()
	display_player_data()

func _on_shell_unlock_requested(shell_id: ShellManager.ShellId) -> void:
	var unlock_cost := ShellManager.SHELL_SPECS[shell_id].unlock_cost
	if player_data.dollars < unlock_cost:
		return #TODO: Feedback insufficient funds
	player_data.dollars -= unlock_cost
	var player_tank_config := player_data.get_tank_config(player_data.selected_tank_id)
	player_tank_config.unlock_shell(shell_id)
	player_data.save()
	display_player_data()

func _on_tank_selected(tank_id: TankManager.TankId) -> void:
	player_data.selected_tank_id = tank_id
	player_data.save()
	display_player_data()

func display_player_data() -> void:
	header_panel.display_player_data()
	tank_list_panel.display_player_data(player_data)
	tank_display_panel.display_tank(player_data)
	upgrade_panel.display_player_data(player_data)
