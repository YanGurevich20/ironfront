class_name ShellSelect
extends Control

@export var is_expanded: bool = false

var shell_counts: Dictionary[ShellSpec, int] = {}
var current_shell_spec: ShellSpec
var tank_spec: TankSpec

@onready var shell_list: BoxContainer = %ShellList
@onready var shell_list_item_scene: PackedScene = preload(
	"res://src/client/arena/touch_controls/shell_select/shell_list_item/shell_list_item.tscn"
)


func _ready() -> void:
	Utils.connect_checked(GameplayBus.shell_fired, _on_shell_fired)
	Utils.connect_checked(
		GameplayBus.reload_progress_left_updated, _on_reload_progress_left_updated
	)
	Utils.connect_checked(
		GameplayBus.online_loadout_state_updated, _on_online_loadout_state_updated
	)
	Utils.connect_checked(
		Account.loadout.selected_tank_spec_updated,
		func(_spec: TankSpec) -> void: _refresh_from_account()
	)
	_refresh_from_account()


func _refresh_from_account() -> void:
	tank_spec = Account.loadout.selected_tank_spec
	var tank_config: TankConfig = Account.loadout.get_selected_tank_config()
	var previous_shell_spec: ShellSpec = current_shell_spec
	var next_shell_counts: Dictionary[ShellSpec, int] = {}
	for shell_spec_key: Variant in tank_config.shell_loadout_by_spec.keys():
		var shell_spec: ShellSpec = shell_spec_key as ShellSpec
		if shell_spec == null:
			continue
		var shell_count: int = int(tank_config.shell_loadout_by_spec[shell_spec_key])
		if shell_count <= 0:
			continue
		next_shell_counts[shell_spec] = shell_count
	shell_counts = next_shell_counts
	_clear_shell_list()
	for shell_spec: ShellSpec in shell_counts.keys():
		var shell_list_item: ShellListItem = shell_list_item_scene.instantiate()
		shell_list.add_child(shell_list_item)
		shell_list_item.display_shell(shell_spec)
		Utils.connect_checked(shell_list_item.shell_selected, _on_shell_selected)
		Utils.connect_checked(shell_list_item.shell_expand_requested, _on_shell_expand_requested)
	update_counts()
	if previous_shell_spec != null and shell_counts.has(previous_shell_spec):
		_on_shell_selected(previous_shell_spec)
	else:
		_select_first_valid_shell()


func _clear_shell_list() -> void:
	for child in shell_list.get_children():
		child.queue_free()


func update_counts() -> void:
	for child_variant: Variant in shell_list.get_children():
		var child: ShellListItem = child_variant as ShellListItem
		if child == null or child.shell_spec == null:
			continue
		child.update_shell_amount(int(shell_counts.get(child.shell_spec, 0)))


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
	if not shell_counts.has(shell.shell_spec):
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


func _on_online_loadout_state_updated(
	selected_shell_id: String, shell_counts_by_id: Dictionary, reload_time_left: float
) -> void:
	if shell_counts.is_empty():
		return
	var selected_shell: ShellSpec = null
	for shell_spec: ShellSpec in shell_counts.keys():
		var shell_id: String = ShellManager.get_shell_id(shell_spec)
		var server_count: int = max(0, int(shell_counts_by_id.get(shell_id, 0)))
		shell_counts[shell_spec] = server_count
		if shell_id == selected_shell_id:
			selected_shell = shell_spec
	update_counts()
	if selected_shell == null:
		return
	current_shell_spec = selected_shell
	GameplayBus.update_remaining_shell_count.emit(shell_counts[selected_shell])
	if shell_counts[selected_shell] <= 0:
		_on_shell_expand_requested()
	if reload_time_left <= 0.0:
		for child: ShellListItem in shell_list.get_children():
			if child.shell_spec == selected_shell:
				child.update_progress_bar(1.0)
				break
