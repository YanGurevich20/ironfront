class_name ShellSelect
extends Control

@export var is_expanded: bool = false

var shell_counts: Dictionary[ShellSpec, int] = {}
var current_shell_spec: ShellSpec
var tank_spec: TankSpec

@onready var shell_list: BoxContainer = %ShellList
@onready var shell_list_item_scene: PackedScene = preload(
	"res://ui/touch_controls/shell_select/shell_list_item/shell_list_item.tscn"
)


func _ready() -> void:
	Utils.connect_checked(GameplayBus.shell_fired, _on_shell_fired)
	Utils.connect_checked(
		GameplayBus.reload_progress_left_updated, _on_reload_progress_left_updated
	)


func initialize() -> void:
	var player_data := PlayerData.get_instance()
	var player_tank_config: PlayerTankConfig = player_data.get_current_tank_config()
	tank_spec = TankManager.tank_specs[player_tank_config.tank_id]
	shell_counts = player_tank_config.shell_amounts.duplicate()
	for shell_spec: ShellSpec in shell_counts.keys():
		if shell_counts[shell_spec] == 0:
			var removed := shell_counts.erase(shell_spec)
			if not removed:
				pass
	for child in shell_list.get_children():
		shell_list.remove_child(child)
		child.queue_free()
	for shell_spec: ShellSpec in shell_counts.keys():
		var shell_list_item: ShellListItem = shell_list_item_scene.instantiate()
		shell_list.add_child(shell_list_item)
		shell_list_item.display_shell(shell_spec)
		Utils.connect_checked(shell_list_item.shell_selected, _on_shell_selected)
		Utils.connect_checked(shell_list_item.shell_expand_requested, _on_shell_expand_requested)
	update_counts()
	_select_first_valid_shell()


func update_counts() -> void:
	for child: ShellListItem in shell_list.get_children():
		child.update_shell_amount(shell_counts[child.shell_spec])


func _on_shell_selected(shell_spec: ShellSpec) -> void:
	current_shell_spec = shell_spec
	for child: ShellListItem in shell_list.get_children():
		if child.shell_spec == shell_spec:
			child.update_is_expanded(false)
		else:
			child.hide()
	_reset_loading_progress_bars()
	GameplayBus.shell_selected.emit(shell_spec, shell_counts[shell_spec])


func _on_shell_expand_requested() -> void:
	for child: ShellListItem in shell_list.get_children():
		child.update_is_expanded(true)
		child.show()


func _select_first_valid_shell() -> void:
	for shell_spec: ShellSpec in shell_counts.keys():
		if shell_counts[shell_spec] > 0:
			_on_shell_selected(shell_spec)
			return


func _on_shell_fired(shell: Shell, tank: Tank) -> void:
	if not tank.is_player:
		return
	shell_counts[shell.shell_spec] -= 1
	if shell_counts[shell.shell_spec] == 0:
		_on_shell_expand_requested()
	update_counts()
	GameplayBus.update_remaining_shell_count.emit(shell_counts[shell.shell_spec])


func _on_reload_progress_left_updated(progress: float, tank: Tank) -> void:
	if not tank.is_player:
		return
	for child: ShellListItem in shell_list.get_children():
		if child.shell_spec == current_shell_spec:
			child.update_progress_bar(progress)
			break


func _reset_loading_progress_bars() -> void:
	for child: ShellListItem in shell_list.get_children():
		child.reset_progress_bar()
