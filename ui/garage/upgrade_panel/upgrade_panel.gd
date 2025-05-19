class_name UpgradePanel extends Control

@onready var modules_button: Button = %ModulesButton
@onready var crew_button: Button = %CrewButton
@onready var equipment_button: Button = %EquipmentButton

@onready var upgrade_list_container: VBoxContainer = %UpgradeListContainer

@onready var modules_upgrade_list: VBoxContainer = %ModuleUpgradeList
@onready var crew_upgrade_list: VBoxContainer = %CrewUpgradeList
@onready var equipment_upgrade_list: VBoxContainer = %EquipmentUpgradeList

func _ready() -> void:
	modules_button.pressed.connect(func()->void: _show_list(modules_upgrade_list, modules_button))
	crew_button.pressed.connect(func()->void: _show_list(crew_upgrade_list, crew_button))
	equipment_button.pressed.connect(func()->void: _show_list(equipment_upgrade_list, equipment_button))
	_show_list(modules_upgrade_list, modules_button)

func _show_list(list_to_show: VBoxContainer, button_pressed: Button) -> void:
	var buttons: Array[Button] = [modules_button, crew_button, equipment_button]
	for button in buttons:
		button.button_pressed = button == button_pressed
	for list in upgrade_list_container.get_children():
		list.visible = list == list_to_show
