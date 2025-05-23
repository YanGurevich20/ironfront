class_name AmmoUpgradeList extends VBoxContainer

@onready var ammo_upgrade_list_item_scene: PackedScene = preload("res://ui/garage/upgrade_panel/ammo_upgrade_list/ammo_upgrade_list_item/ammo_upgrade_list_item.tscn")

var max_allowed_count: int
var player_data: PlayerData
signal shell_unlock_requested(shell_id: ShellManager.ShellId)

func display_ammo_upgrade_list(_player_data: PlayerData) -> void:
	player_data = _player_data
	var tank_config: PlayerTankConfig = player_data.get_current_tank_config()
	Utils.print_resource_properties(tank_config)
	for child in get_children():
		child.queue_free()
	var tank_spec := TankManager.get_tank_spec(tank_config.tank_id)
	max_allowed_count = tank_spec.shell_capacity
	for shell_id: ShellManager.ShellId in tank_spec.allowed_shells:
		var list_item: AmmoUpgradeListItem = ammo_upgrade_list_item_scene.instantiate()
		add_child(list_item)
		list_item.display_shell(tank_config, shell_id)
		list_item.count_updated.connect(_on_count_updated)

func _on_count_updated(_shell_id: ShellManager.ShellId, count: int) -> void:
	var unallocated_count := max_allowed_count
	for item: AmmoUpgradeListItem in get_children():
		unallocated_count -= item.current_count
	for item: AmmoUpgradeListItem in get_children():
		item.current_allowed_count = item.current_count + unallocated_count
	var current_tank_config := player_data.get_current_tank_config()
	current_tank_config.set_shell_amount(_shell_id, count)
	player_data.save()
