class_name FireButton extends Control

@onready var button_sprite:= $ButtonSprite
@onready var button_click:= $ButtonClick

var is_button_pressed := false

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		is_button_pressed = event.pressed
		button_click.pitch_scale = 0.9 if event.pressed else 1.1
		button_click.play()
		if event.pressed:
			SignalBus.fire_input.emit()
	button_sprite.frame = 1 if is_button_pressed else 0

func reset_input() -> void:
	is_button_pressed = false
