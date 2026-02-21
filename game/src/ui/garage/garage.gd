class_name Garage
extends Control

var player_data: PlayerData = PlayerData.get_instance()
var preferences: Preferences = Preferences.get_instance()
var account: Account = Account.get_instance()

@onready var header_panel: HeaderPanel = %HeaderPanel
@onready var upgrade_panel: UpgradePanel = %UpgradePanel
@onready var tank_list_panel: TankListPanel = %TankListPanel
@onready var tank_display_panel: TankDisplayPanel = %TankDisplayPanel


func _ready() -> void:
	Utils.connect_checked(tank_list_panel.unlock_tank_requested, _on_tank_unlock_requested)
	Utils.connect_checked(UiBus.shell_unlock_requested, _on_shell_unlock_requested)
	Utils.connect_checked(GameplayBus.level_finished, display_player_data)
	Utils.connect_checked(GameplayBus.player_data_changed, display_player_data)
	display_player_data()


func _on_tank_unlock_requested(tank_id: String) -> void:
	var tank_spec: TankSpec = TankManager.tank_specs.get(tank_id)
	if tank_spec == null:
		return
	if account.economy.dollars < tank_spec.dollar_cost:
		return  #TODO: Feedback insufficient funds
	account.economy.dollars -= tank_spec.dollar_cost
	account.save()
	player_data.unlock_tank(tank_id)
	player_data.save()
	display_player_data()


func _on_shell_unlock_requested(shell_spec: ShellSpec) -> void:
	var unlock_cost := shell_spec.unlock_cost
	if account.economy.dollars < unlock_cost:
		return  #TODO: Feedback insufficient funds
	account.economy.dollars -= unlock_cost
	account.save()
	var player_tank_config := player_data.get_tank_config(preferences.selected_tank_id)
	player_tank_config.unlock_shell(shell_spec)
	player_data.save()
	display_player_data()


func display_player_data() -> void:
	tank_list_panel.display_player_data(player_data)
	upgrade_panel.display_player_data(player_data)


func show_online_join_feedback(message: String, is_error: bool) -> void:
	header_panel.display_online_feedback(message, is_error)
