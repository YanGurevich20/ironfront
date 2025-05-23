class_name FireButton extends Control

@onready var button_sprite:= $ButtonSprite
@onready var button_click:= $ButtonClick

signal fire_button_pressed
var is_pressed: bool = false

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		update_state(event.pressed)
		if event.pressed:
			fire_button_pressed.emit()

func update_state(new_state: bool) -> void:
	if new_state == is_pressed: return
	button_click.pitch_scale = 0.9 if new_state else 1.1
	button_click.play()
	button_sprite.frame = 1 if new_state else 0
	is_pressed = new_state

func reset_input() -> void:
	update_state(false)
