extends Control

@onready var left_lever := $LeftLever
@onready var right_lever := $RightLever
@onready var traverse_wheel := $TraverseWheel
@onready var fire_button: FireButton = $FireButton
@onready var shell_select: ShellSelect = $ShellSelect

func reset_input() -> void:
	left_lever.reset_input()
	right_lever.reset_input()
	traverse_wheel.reset_input()
	fire_button.reset_input()
	
func set_shells(shells: Array[ShellSpec]) -> void:
	if shell_select == null:
		return
	shell_select.all_shells = shells
