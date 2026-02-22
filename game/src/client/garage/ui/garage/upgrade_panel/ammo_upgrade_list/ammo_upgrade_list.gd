class_name AmmoUpgradeList
extends VBoxContainer

signal shell_unlock_requested(shell_spec: ShellSpec)

var max_allowed_count: int
var selected_tank_spec: TankSpec

@onready var ammo_upgrade_list_item_scene: PackedScene = preload(
	(
		"res://src/client/garage/ui/garage/upgrade_panel/ammo_upgrade_list/"
		+ "ammo_upgrade_list_item/ammo_upgrade_list_item.tscn"
	)
)


func clear_list() -> void:
	for child in get_children():
		child.queue_free()


func display_tank_loadout(tank_spec: TankSpec, tank_config: TankConfig) -> void:
	selected_tank_spec = tank_spec
	clear_list()
	assert(tank_spec != null, "Missing tank spec")
	max_allowed_count = tank_spec.shell_capacity
	for shell_spec: ShellSpec in tank_spec.allowed_shells:
		var list_item: AmmoUpgradeListItem = ammo_upgrade_list_item_scene.instantiate()
		add_child(list_item)
		list_item.display_shell(tank_spec, tank_config, shell_spec)
		Utils.connect_checked(list_item.count_updated, _on_count_updated)


func _on_count_updated() -> void:
	var tank_config: TankConfig = Account.loadout.get_selected_tank_config()
	var current_total_count: int = 0
	for shell_count_variant: Variant in tank_config.shell_loadout_by_spec.values():
		current_total_count += int(shell_count_variant)
	var unallocated_count := max_allowed_count - current_total_count
	for item: AmmoUpgradeListItem in get_children():
		item.current_allowed_count = item.current_count + unallocated_count
		item.update_buttons()
