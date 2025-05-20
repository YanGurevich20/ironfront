class_name ShellSelect extends Control

@onready var shell_list: VBoxContainer = %ShellList
@onready var shell_list_item_scene: PackedScene = preload("res://ui/touch_controls/shell_select/shell_list_item/shell_list_item.tscn")

@export var shells: Array[ShellSpec] = []:
	set(value):
		shells = value
		display_shells()

func display_shells() -> void:
	for child in shell_list.get_children():
		child.queue_free()

	for shell in shells:
		var shell_list_item: ShellListItem = shell_list_item_scene.instantiate()
		shell_list_item.shell_spec = shell
		shell_list.add_child(shell_list_item)

func _ready() -> void:
	pass


