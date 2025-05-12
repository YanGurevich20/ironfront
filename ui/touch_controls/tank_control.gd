extends Control

@onready var left_lever := $LeftLever
@onready var right_lever := $RightLever
@onready var traverse_wheel := $TraverseWheel
@onready var fire_button := $FireButton

func _ready() -> void:
	left_lever.lever_moved.connect(_on_lever_input)
	right_lever.lever_moved.connect(_on_lever_input)
	traverse_wheel.wheel_rotated.connect(_on_wheel_rotated)
	fire_button.fire_button_pressed.connect(_on_fire_button_pressed)

func reset_input() -> void:
	left_lever.reset_input()
	right_lever.reset_input()
	traverse_wheel.reset_input()
	fire_button.reset_input()

func _on_lever_input(lever_side: Lever.Side, value: float) -> void:
	SignalBus.lever_input.emit(lever_side,value)
func _on_wheel_rotated(value:float) -> void:
	SignalBus.wheel_input.emit(value)
func _on_fire_button_pressed() -> void:
	SignalBus.fire_input.emit()
