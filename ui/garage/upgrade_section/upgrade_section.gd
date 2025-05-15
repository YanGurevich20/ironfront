class_name UpgradeSection extends VBoxContainer

@onready var modules_button: Button = %ModulesButton
@onready var crew_button: Button = %CrewButton
@onready var equipment_button: Button = %EquipmentButton

@onready var upgrade_list_container: VBoxContainer = %UpgradeListContainer

@onready var modules_upgrade_list: VBoxContainer = %ModulesUpgradeList
@onready var crew_upgrade_list: VBoxContainer = %CrewUpgradeList
@onready var equipment_upgrade_list: VBoxContainer = %EquipmentUpgradeList

func _ready() -> void:
	modules_button.pressed.connect(func()->void: _view_upgrade_list(modules_upgrade_list))
	crew_button.pressed.connect(func()->void: _view_upgrade_list(crew_upgrade_list))
	equipment_button.pressed.connect(func()->void: _view_upgrade_list(equipment_upgrade_list))

func _view_upgrade_list(list_to_show: VBoxContainer) -> void:
	for list: VBoxContainer in [modules_upgrade_list, crew_upgrade_list, equipment_upgrade_list]:
		list.visible = list == list_to_show
	upgrade_list_container.visible = true