class_name ShellSelect extends Control

@onready var shell_list: BoxContainer = %ShellList
@onready var shell_list_item_scene: PackedScene = preload("res://ui/touch_controls/shell_select/shell_list_item/shell_list_item.tscn")

@export var is_expanded: bool = false
var shell_counts: Dictionary[ShellManager.ShellId, int] = {}
var current_shell_id: ShellManager.ShellId

func _ready() -> void:
	SignalBus.shell_fired.connect(_on_shell_fired)
	SignalBus.reload_progress_left_updated.connect(_on_reload_progress_left_updated)

func initialize() -> void:
	var player_data := PlayerData.get_instance()
	var player_tank_config: PlayerTankConfig = player_data.get_current_tank_config()
	shell_counts = player_tank_config.shells.duplicate()
	for shell_id: ShellManager.ShellId in shell_counts.keys():
		if shell_counts[shell_id] == 0:
			shell_counts.erase(shell_id)
	for child in shell_list.get_children():
		shell_list.remove_child(child)
		child.queue_free()
	for shell_id: ShellManager.ShellId in shell_counts.keys():
		var shell_list_item: ShellListItem = shell_list_item_scene.instantiate()
		shell_list.add_child(shell_list_item)
		shell_list_item.display_shell(shell_id)
		shell_list_item.shell_selected.connect(_on_shell_selected)
		shell_list_item.shell_expand_requested.connect(_on_shell_expand_requested)
	update_counts()
	_select_first_valid_shell()

func update_counts() -> void:
	for child: ShellListItem in shell_list.get_children():
		child.update_shell_amount(shell_counts[child.shell_id])

func _on_shell_selected(shell_id: ShellManager.ShellId) -> void:
	current_shell_id = shell_id
	for child: ShellListItem in shell_list.get_children():
		if child.shell_id == shell_id:
			child.update_is_expanded(false)
		else:
			child.hide()
	_reset_loading_progress_bars()
	SignalBus.shell_selected.emit(shell_id, shell_counts[shell_id])

func _on_shell_expand_requested() -> void:
	for child: ShellListItem in shell_list.get_children():
		child.update_is_expanded(true)
		child.show()

func _select_first_valid_shell() -> void:
	for shell_id: ShellManager.ShellId in shell_counts.keys():
		if shell_counts[shell_id] > 0:
			_on_shell_selected(shell_id)
			return

func _on_shell_fired(shell: Shell, tank: Tank) -> void:
	if not tank.is_player: return
	shell_counts[shell.shell_id] -= 1
	if shell_counts[shell.shell_id] == 0:
		_on_shell_expand_requested()
	update_counts()
	SignalBus.update_remaining_shell_count.emit(shell_counts[shell.shell_id])

func _on_reload_progress_left_updated(progress: float, tank: Tank) -> void:
	if not tank.is_player: return
	for child: ShellListItem in shell_list.get_children():
		if child.shell_id == current_shell_id:
			child.update_progress_bar(progress)
			break

func _reset_loading_progress_bars() -> void:
	for child: ShellListItem in shell_list.get_children():
		child.reset_progress_bar()
