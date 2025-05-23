extends Control

@onready var left_lever := $LeftLever
@onready var right_lever := $RightLever
@onready var traverse_wheel := $TraverseWheel
@onready var fire_button: FireButton = $FireButton
@onready var shell_select: ShellSelect = $ShellSelect
@onready var pause_button: Button = %PauseButton

var _current_shell_id: ShellManager.ShellId

func _ready() -> void:
	SignalBus.shell_selected.connect(func(shell_id: ShellManager.ShellId) -> void:
		print("shell_selected: %s" % ShellManager.ShellId.find_key(shell_id))
		_current_shell_id = shell_id
	)
	fire_button.fire_button_pressed.connect(func() -> void:
		SignalBus.fire_input.emit(_current_shell_id)
	)

	pause_button.pressed.connect(func() -> void:
		SignalBus.pause_input.emit()
	)

func reset_input() -> void:
	left_lever.reset_input()
	right_lever.reset_input()
	traverse_wheel.reset_input()
	fire_button.reset_input()
	
func display_controls() -> void:
	shell_select.display_shells()