class_name ShellSelect extends Control

@onready var shell_list: BoxContainer = %ShellList
@onready var shell_list_item_scene: PackedScene = preload("res://ui/touch_controls/shell_select/shell_list_item/shell_list_item.tscn")

@export var is_expanded: bool = false
var shell_counts: Dictionary[ShellManager.ShellId, int] = {}
var current_shell_id: ShellManager.ShellId

func display_shells() -> void:
	for child in shell_list.get_children():
		child.queue_free()
	var player_data: PlayerData = LoadableData.get_instance(PlayerData)
	var player_tank_config: PlayerTankConfig = player_data.get_current_tank_config()
	shell_counts = player_tank_config.shells
	for shell_id: ShellManager.ShellId in shell_counts.keys():
		if shell_counts[shell_id] == 0:
			continue
		var shell_list_item: ShellListItem = shell_list_item_scene.instantiate()
		shell_list.add_child(shell_list_item)
		shell_list_item.display_shell(shell_id, shell_counts[shell_id])
		shell_list_item.shell_selected.connect(_on_shell_selected)
		shell_list_item.shell_expand_requested.connect(_on_shell_expand_requested)
	_select_first_valid_shell()

func _on_shell_selected(shell_id: ShellManager.ShellId) -> void:
	current_shell_id = shell_id
	for child: ShellListItem in shell_list.get_children():
		if child.shell_id == shell_id:
			child.update_is_expanded(false)
		else:
			child.hide()
	SignalBus.shell_selected.emit(shell_id)

func _on_shell_expand_requested() -> void:
	for child: ShellListItem in shell_list.get_children():
		child.update_is_expanded(true)
		child.show()

func _select_first_valid_shell() -> void:
	for shell_id: ShellManager.ShellId in shell_counts.keys():
		if shell_counts[shell_id] > 0:
			_on_shell_selected(shell_id)
			return