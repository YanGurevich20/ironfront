class_name Garage
extends Control

signal play_requested

@onready var header_panel: HeaderPanel = %HeaderPanel
@onready var tank_list_panel: TankListPanel = %TankListPanel
@onready var tank_display_panel: TankDisplayPanel = %TankDisplayPanel


func _ready() -> void:
	Utils.connect_checked(header_panel.play_requested, func() -> void: play_requested.emit())
	Utils.connect_checked(tank_list_panel.unlock_tank_requested, _on_tank_unlock_requested)
	Utils.connect_checked(UiBus.shell_unlock_requested, _on_shell_unlock_requested)


func _on_tank_unlock_requested(tank_spec: TankSpec) -> void:
	assert(tank_spec != null, "Missing tank spec")
	if Account.economy.dollars < tank_spec.dollar_cost:
		return
	Account.economy.dollars -= tank_spec.dollar_cost
	Account.loadout.unlock_tank(tank_spec)


func _on_shell_unlock_requested(shell_spec: ShellSpec) -> void:
	var unlock_cost := shell_spec.unlock_cost
	if Account.economy.dollars < unlock_cost:
		return
	var tank_config: TankConfig = Account.loadout.get_selected_tank_config()
	Account.economy.dollars -= unlock_cost
	if not tank_config.unlocked_shell_specs.has(shell_spec):
		tank_config.unlocked_shell_specs.append(shell_spec)
	if not tank_config.shell_loadout_by_spec.has(shell_spec):
		tank_config.shell_loadout_by_spec[shell_spec] = 0


func show_online_join_feedback(message: String, is_error: bool) -> void:
	header_panel.display_online_feedback(message, is_error)
