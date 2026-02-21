class_name AmmoUpgradeList
extends VBoxContainer

signal shell_unlock_requested(shell_spec: ShellSpec)

var max_allowed_count: int
var player_data: PlayerData
var preferences: Preferences = Preferences.get_instance()

@onready var ammo_upgrade_list_item_scene: PackedScene = preload(
	(
		"res://src/ui/garage/upgrade_panel/ammo_upgrade_list/"
		+ "ammo_upgrade_list_item/ammo_upgrade_list_item.tscn"
	)
)


func display_ammo_upgrade_list(player_data_input: PlayerData) -> void:
	player_data = player_data_input
	var tank_config: PlayerTankConfig = player_data.get_selected_tank_config(
		preferences.selected_tank_id
	)
	for child in get_children():
		child.queue_free()
	var tank_spec: TankSpec = TankManager.tank_specs.get(tank_config.tank_id)
	if tank_spec == null:
		return
	max_allowed_count = tank_spec.shell_capacity
	for shell_spec: ShellSpec in tank_spec.allowed_shells:
		var list_item: AmmoUpgradeListItem = ammo_upgrade_list_item_scene.instantiate()
		add_child(list_item)
		list_item.display_shell(tank_config, shell_spec)
		Utils.connect_checked(list_item.count_updated, _on_count_updated)


func _on_count_updated() -> void:
	var tank_config: PlayerTankConfig = player_data.get_selected_tank_config(
		preferences.selected_tank_id
	)
	var current_total_count := tank_config.get_total_shell_count()
	var unallocated_count := max_allowed_count - current_total_count
	for item: AmmoUpgradeListItem in get_children():
		item.current_allowed_count = item.current_count + unallocated_count
		item.update_buttons()
