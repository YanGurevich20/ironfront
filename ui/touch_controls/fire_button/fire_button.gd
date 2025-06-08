class_name FireButton extends Control

@onready var button_sprite:AnimatedSprite2D= $ButtonSprite
@onready var button_click:AudioStreamPlayer= $ButtonClick

signal fire_button_pressed
var is_pressed: bool = false

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event
		update_state(touch_event.pressed)
		if touch_event.pressed:
			fire_button_pressed.emit()

func update_state(new_state: bool) -> void:
	if new_state == is_pressed: return
	button_click.pitch_scale = 0.9 if new_state else 1.1
	button_click.play()
	button_sprite.frame = 1 if new_state else 0
	is_pressed = new_state

func reset_input() -> void:
	update_state(false)
