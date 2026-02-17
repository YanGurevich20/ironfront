class_name AmmoUpgradeList
extends VBoxContainer

signal shell_unlock_requested(shell_spec: ShellSpec)

var max_allowed_count: int
var player_data: PlayerData

@onready var ammo_upgrade_list_item_scene: PackedScene = preload(
	(
		"res://src/ui/garage/upgrade_panel/ammo_upgrade_list/"
		+ "ammo_upgrade_list_item/ammo_upgrade_list_item.tscn"
	)
)


func display_ammo_upgrade_list(player_data_input: PlayerData) -> void:
	player_data = player_data_input
	var tank_config: PlayerTankConfig = player_data.get_current_tank_config()
	for child in get_children():
		child.queue_free()
	var tank_spec := TankManager.tank_specs[tank_config.tank_id]
	max_allowed_count = tank_spec.shell_capacity
	for shell_spec: ShellSpec in tank_spec.allowed_shells:
		var list_item: AmmoUpgradeListItem = ammo_upgrade_list_item_scene.instantiate()
		add_child(list_item)
		list_item.display_shell(tank_config, shell_spec, player_data.dollars)
		Utils.connect_checked(list_item.count_updated, _on_count_updated)


func _on_count_updated() -> void:
	var current_total_count := player_data.get_current_tank_config().get_total_shell_count()
	var unallocated_count := max_allowed_count - current_total_count
	for item: AmmoUpgradeListItem in get_children():
		item.current_allowed_count = item.current_count + unallocated_count
		item.update_buttons()
