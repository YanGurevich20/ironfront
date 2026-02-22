class_name Garage
extends Control

var player_data: PlayerData = PlayerData.get_instance()

@onready var header_panel: HeaderPanel = %HeaderPanel
@onready var tank_list_panel: TankListPanel = %TankListPanel
@onready var tank_display_panel: TankDisplayPanel = %TankDisplayPanel


func _ready() -> void:
	Utils.connect_checked(tank_list_panel.unlock_tank_requested, _on_tank_unlock_requested)
	Utils.connect_checked(UiBus.shell_unlock_requested, _on_shell_unlock_requested)


func _on_tank_unlock_requested(tank_id: String) -> void:
	var tank_spec: TankSpec = TankManager.tank_specs.get(tank_id, null)
	assert(tank_spec != null, "Missing tank spec for tank_id=%s" % tank_id)
	if Account.economy.dollars < tank_spec.dollar_cost:
		return  #TODO: Feedback insufficient funds
	Account.economy.dollars -= tank_spec.dollar_cost
	player_data.unlock_tank(tank_id)
	player_data.save()


func _on_shell_unlock_requested(shell_spec: ShellSpec) -> void:
	var unlock_cost := shell_spec.unlock_cost
	if Account.economy.dollars < unlock_cost:
		return  #TODO: Feedback insufficient funds
	var tank_config: TankConfig = Account.loadout.get_selected_tank_config()
	if tank_config == null:
		return
	var shell_id: String = ShellManager.get_shell_id(shell_spec)
	Account.economy.dollars -= unlock_cost
	if not tank_config.unlocked_shell_ids.has(shell_id):
		tank_config.unlocked_shell_ids.append(shell_id)
	if not tank_config.shell_loadout_by_id.has(shell_id):
		tank_config.shell_loadout_by_id[shell_id] = 0


func show_online_join_feedback(message: String, is_error: bool) -> void:
	header_panel.display_online_feedback(message, is_error)
