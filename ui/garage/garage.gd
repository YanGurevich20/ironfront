class_name Garage
extends Control

signal garage_menu_pressed

var player_data: PlayerData = PlayerData.get_instance()

@onready var header_panel: HeaderPanel = %HeaderPanel
@onready var upgrade_panel: UpgradePanel = %UpgradePanel
@onready var tank_list_panel: TankListPanel = %TankListPanel
@onready var tank_display_panel: TankDisplayPanel = %TankDisplayPanel


func _ready() -> void:
	Utils.connect_checked(
		header_panel.garage_menu_pressed, func() -> void: garage_menu_pressed.emit()
	)
	Utils.connect_checked(tank_list_panel.unlock_tank_requested, _on_tank_unlock_requested)
	Utils.connect_checked(tank_list_panel.tank_selected, _on_tank_selected)
	Utils.connect_checked(SignalBus.shell_unlock_requested, _on_shell_unlock_requested)
	Utils.connect_checked(SignalBus.level_finished_and_saved, display_player_data)
	display_player_data()


func _on_tank_unlock_requested(tank_id: TankManager.TankId) -> void:
	var tank_spec: TankSpec = TankManager.tank_specs[tank_id]
	if player_data.dollars < tank_spec.dollar_cost:
		return  #TODO: Feedback insufficient funds
	player_data.dollars -= tank_spec.dollar_cost
	player_data.unlock_tank(tank_id)
	player_data.save()
	display_player_data()


func _on_shell_unlock_requested(shell_spec: ShellSpec) -> void:
	var unlock_cost := shell_spec.unlock_cost
	if player_data.dollars < unlock_cost:
		return  #TODO: Feedback insufficient funds
	player_data.dollars -= unlock_cost
	var player_tank_config := player_data.get_tank_config(player_data.selected_tank_id)
	player_tank_config.unlock_shell(shell_spec)
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


func show_online_join_feedback(message: String, is_error: bool) -> void:
	header_panel.display_online_feedback(message, is_error)
