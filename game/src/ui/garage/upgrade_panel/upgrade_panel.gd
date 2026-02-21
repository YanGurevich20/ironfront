class_name UpgradePanel
extends Control

var is_tank_selected: bool = false
var preferences: Preferences = Preferences.get_instance()

@onready var modules_button: Button = %ModulesButton
@onready var crew_button: Button = %CrewButton
@onready var equipment_button: Button = %EquipmentButton
@onready var ammo_button: Button = %AmmoButton
@onready var upgrade_list_container: VBoxContainer = %UpgradeListContainer
@onready var modules_upgrade_list: VBoxContainer = %ModuleUpgradeList
@onready var crew_upgrade_list: VBoxContainer = %CrewUpgradeList
@onready var equipment_upgrade_list: VBoxContainer = %EquipmentUpgradeList
@onready var ammo_upgrade_list: AmmoUpgradeList = %AmmoUpgradeList
@onready var buttons: Array[Button] = [modules_button, crew_button, equipment_button, ammo_button]
@onready var select_tank_warning: Control = %SelectTankWarning


func _ready() -> void:
	Utils.connect_checked(
		modules_button.pressed, func() -> void: _show_list(modules_upgrade_list, modules_button)
	)
	Utils.connect_checked(
		crew_button.pressed, func() -> void: _show_list(crew_upgrade_list, crew_button)
	)
	Utils.connect_checked(
		equipment_button.pressed,
		func() -> void: _show_list(equipment_upgrade_list, equipment_button)
	)
	Utils.connect_checked(
		ammo_button.pressed, func() -> void: _show_list(ammo_upgrade_list, ammo_button)
	)
	Utils.connect_checked(
		preferences.selected_tank_id_updated,
		func(_tank_id: String) -> void: display_player_data(PlayerData.get_instance())
	)


func _show_list(list_to_show: VBoxContainer, button_pressed: Button) -> void:
	if not is_tank_selected:
		return
	for button in buttons:
		button.button_pressed = button == button_pressed
	for list: Control in upgrade_list_container.get_children():
		list.visible = list == list_to_show


func display_player_data(player_data: PlayerData) -> void:
	var selected_tank_id: String = preferences.selected_tank_id
	if not player_data.is_tank_unlocked(selected_tank_id):
		is_tank_selected = false
		select_tank_warning.visible = true
		return
	is_tank_selected = true
	select_tank_warning.visible = false
	ammo_upgrade_list.display_ammo_upgrade_list(player_data, selected_tank_id)
	_show_list(ammo_upgrade_list, ammo_button)
