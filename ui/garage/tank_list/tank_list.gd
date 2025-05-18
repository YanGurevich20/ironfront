class_name TankListPanel extends Control

@onready var tank_list: HBoxContainer = %TankList
@onready var _tank_list_item_scene: PackedScene = preload("res://ui/garage/tank_list/tank_list_item.tscn")

func _ready() -> void:
	for child in tank_list.get_children():
		tank_list.remove_child(child)
		child.queue_free()
	var all_tanks: Array[TankSpec] = TankManager.TANK_SPECS.values()
	var unlocked_tank_ids: Array[String] = LoadableData.get_instance(GameProgress).unlocked_tank_ids
	print("unlocked_tank_ids: ", unlocked_tank_ids)
	for tank_spec in all_tanks:
		var tank_list_item: TankListItem = _tank_list_item_scene.instantiate()
		tank_list_item.pressed.connect(func()->void: _select_tank(tank_list_item))
		tank_list.add_child(tank_list_item)
		if unlocked_tank_ids.has(tank_spec.id):
			tank_list_item._unlock_tank()
		tank_list_item.display_tank(tank_spec)
	_select_tank(tank_list.get_child(0))

func _select_tank(tank_list_item: TankListItem) -> void:
	for item in tank_list.get_children():
		item.button_pressed = item == tank_list_item
