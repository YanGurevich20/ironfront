class_name TankControl extends Control

@onready var left_lever :Lever= $LeftLever
@onready var right_lever :Lever= $RightLever
@onready var traverse_wheel :TraverseWheel= $TraverseWheel
@onready var fire_button: FireButton = $FireButton
@onready var shell_select: ShellSelect = % ShellSelect

@onready var pause_button: Button = %PauseButton

func _ready() -> void:
	fire_button.fire_button_pressed.connect(func() -> void: SignalBus.fire_input.emit())
	pause_button.pressed.connect(func() -> void: SignalBus.pause_input.emit())

func reset_input() -> void:
	left_lever.reset_input()
	right_lever.reset_input()
	traverse_wheel.reset_input()
	fire_button.reset_input()

func display_controls() -> void:
	shell_select.initialize()
