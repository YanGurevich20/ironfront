class_name TankListPanel extends Panel

@onready var tank_list: HBoxContainer = %TankList
var tank_list_item_scene := preload("res://ui/garage/tank_list/tank_list_item.tscn")

func display_tanks(tank_specs: Dictionary) -> void:
	# Remove existing items
	for child in tank_list.get_children():
		tank_list.remove_child(child)
		child.queue_free()

	# Add a TankListItem for each tank
	for tank_type: TankManager.TankType in tank_specs.keys():
		print(tank_type)
		var tank_spec: TankSpec = tank_specs[tank_type]
		var item: TankListItem = tank_list_item_scene.instantiate()
		item.tank_name = tank_spec.display_name
		item.tank_image = tank_spec.preview_texture
		tank_list.add_child(item)
