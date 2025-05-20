class_name ShellSelect extends Control

@onready var shell_list: BoxContainer = %ShellList
@onready var shell_list_item_scene: PackedScene = preload("res://ui/touch_controls/shell_select/shell_list_item/shell_list_item.tscn")

@export var is_expanded: bool = false

@export var all_shells: Array[ShellSpec]

# Keeps track of the list item that should currently receive the reload progress updates.
var _current_shell_item: ShellListItem = null

# The spec of the shell that is currently selected (and therefore whose item should receive progress updates).
var _selected_shell_spec: ShellSpec = null

func _ready() -> void:
	# Guard against an empty list of shells.
	if all_shells.is_empty():
		return

	_selected_shell_spec = all_shells[0]
	display_shells([_selected_shell_spec])

	# After the initial list is displayed (collapsed) register the lone shell item for reload progress updates.
	_update_current_shell_item_connection()

func display_shells(shells_to_display: Array[ShellSpec]) -> void:
	# Re-build the list from scratch.
	for child in shell_list.get_children():
		child.queue_free()

	for shell_spec in shells_to_display:
		var list_item: ShellListItem = shell_list_item_scene.instantiate()
		list_item.shell_spec = shell_spec
		list_item.shell_pressed.connect(_on_shell_pressed)
		shell_list.add_child(list_item)

	_update_list_items_expansion()
	# Whenever the list is rebuilt we need to refresh which item (if any) receives reload-progress updates.
	_update_current_shell_item_connection()

func _on_shell_pressed(shell_spec: ShellSpec) -> void:
	# Update the current selection to the item the user just tapped.
	_selected_shell_spec = shell_spec

	if is_expanded:
		SignalBus.shell_selected.emit(shell_spec)
		display_shells([shell_spec])
	else:
		display_shells(all_shells)
	is_expanded = !is_expanded
	_update_list_items_expansion()

	# Update which item should receive progress updates based on the new expanded / collapsed state.
	_update_current_shell_item_connection()

func _update_list_items_expansion() -> void:
	if shell_list == null:
		return
	for child in shell_list.get_children():
		if child is ShellListItem:
			child.expand(is_expanded)

# --- Helper methods ---------------------------------------------------------

func _update_current_shell_item_connection() -> void:
	# Disconnect the previously selected shell item (if any) from reload-progress updates.
	if _current_shell_item != null and SignalBus.reload_progress_left_updated.is_connected(_current_shell_item.update_progress_bar):
		SignalBus.reload_progress_left_updated.disconnect(_current_shell_item.update_progress_bar)

	if _current_shell_item != null:
		_current_shell_item.reset_progress_bar()

	_current_shell_item = null

	# Locate the item representing the currently selected shell.
	for child in shell_list.get_children():
		if child is ShellListItem:
			if child.shell_spec == _selected_shell_spec:
				_current_shell_item = child
			else:
				child.reset_progress_bar()

	# Re-establish the connection for the newly selected item (if found).
	if _current_shell_item != null and not SignalBus.reload_progress_left_updated.is_connected(_current_shell_item.update_progress_bar):
		SignalBus.reload_progress_left_updated.connect(_current_shell_item.update_progress_bar)

func _reset_all_progress_bars_except(ignore_item: ShellListItem) -> void:
	for child in shell_list.get_children():
		if child is ShellListItem and child != ignore_item:
			child.reset_progress_bar()
