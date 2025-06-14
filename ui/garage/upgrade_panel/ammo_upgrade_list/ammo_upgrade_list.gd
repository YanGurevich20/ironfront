class_name AmmoUpgradeList extends VBoxContainer

@onready var ammo_upgrade_list_item_scene: PackedScene = preload("res://ui/garage/upgrade_panel/ammo_upgrade_list/ammo_upgrade_list_item/ammo_upgrade_list_item.tscn")

var max_allowed_count: int
var player_data: PlayerData
signal shell_unlock_requested(shell_spec: ShellSpec)

func display_ammo_upgrade_list(_player_data: PlayerData) -> void:
	player_data = _player_data
	var tank_config: PlayerTankConfig = player_data.get_current_tank_config()
	for child in get_children():
		child.queue_free()
	var tank_spec := TankManager.TANK_SPECS[tank_config.tank_id]
	max_allowed_count = tank_spec.shell_capacity
	for shell_spec: ShellSpec in tank_spec.allowed_shells:
		var list_item: AmmoUpgradeListItem = ammo_upgrade_list_item_scene.instantiate()
		add_child(list_item)
		list_item.display_shell(tank_config, shell_spec)
		list_item.count_updated.connect(_on_count_updated)

func _on_count_updated() -> void:
	var current_total_count := player_data.get_current_tank_config().get_total_shell_count()
	var unallocated_count := max_allowed_count - current_total_count
	for item: AmmoUpgradeListItem in get_children():
		item.current_allowed_count = item.current_count + unallocated_count
		item.update_buttons()
