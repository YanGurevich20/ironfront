class_name Lever
extends Control

@warning_ignore("unused_signal")
signal lever_moved(lever_side: LeverSide, value: float)

enum LeverSide { LEFT = 0, RIGHT = 1 }

const TOTAL_FRAMES: int = 7
const CENTER_FRAME: int = 3
const LOCK_THRESHOLD: float = 100.0

@export var lever_side: LeverSide

var should_lock_last_value := false
var touch_y_position := 0.0
var lever_value := 0.0
var last_value := 0.0
var start_position: Vector2

@onready var lever_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var click_small: AudioStreamPlayer = $LeverClickSmall
@onready var click_large: AudioStreamPlayer = $LeverClickLarge
@onready var control_field_height := size.y
@onready var step_size := control_field_height / TOTAL_FRAMES


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)
	else:
		return
	update_lever()


func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if should_lock_last_value:
			play_large_click(1.5)
		start_position = event.position
		touch_y_position = event.position.y
	else:
		var should_lock: bool = abs(start_position.x - event.position.x) > LOCK_THRESHOLD
		touch_y_position = event.position.y if should_lock else control_field_height / 2


func _handle_drag(event: InputEventScreenDrag) -> void:
	var should_lock: bool = abs(start_position.x - event.position.x) > LOCK_THRESHOLD
	if should_lock != should_lock_last_value:
		play_large_click(1.0 if should_lock else 1.5)
		should_lock_last_value = should_lock
	touch_y_position = event.position.y


func play_large_click(pitch: float) -> void:
	click_large.pitch_scale = pitch
	click_large.play()


func update_lever() -> void:
	var step: int = clamp(floor(touch_y_position / step_size), 0, TOTAL_FRAMES - 1)
	lever_sprite.frame = step

	var relative_step: int = CENTER_FRAME - step
	lever_value = float(relative_step) / float(CENTER_FRAME)

	if lever_value != last_value:
		click_small.pitch_scale = randfn(0.7, 0.03)
		click_small.play()
		last_value = lever_value
		SignalBus.lever_input.emit(lever_side, lever_value)


func reset_input() -> void:
	touch_y_position = control_field_height / 2
	start_position = Vector2.ZERO
	should_lock_last_value = false
	lever_sprite.frame = int(CENTER_FRAME)
	lever_value = 0.0
	last_value = 0.0
	update_lever()
