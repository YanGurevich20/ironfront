class_name TraverseWheel
extends Control

signal wheel_rotated(speed: float)

@export var max_turn_speed: float = 20.0  # Radians/sec for full input
@export var acceleration: float = 10.0  # How quickly it interpolates

@onready var wheel: Sprite2D = $TraverseWheelSprite
@onready var middle_point: Vector2 = size / 2

var last_angle := 0.0
var last_time := 0.0

var target_speed := 0.0
var current_speed := 0.0

func _ready() -> void:
	set_process(true)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if !event.pressed:
			# Finger lifted: stop target speed, start deceleration
			target_speed = 0.0
			return
		last_angle = (event.position - middle_point).angle()
		last_time = Time.get_ticks_msec() / 1000.0
	elif event is InputEventScreenDrag:
		var now: float = Time.get_ticks_msec() / 1000.0
		var angle: float = (event.position - middle_point).angle()
		var delta_angle: float = wrapf(angle - last_angle, -PI, PI)
		var delta_time: float = now - last_time
		if delta_time > 0:
			var angular_velocity: float = delta_angle / delta_time
			target_speed = clamp(angular_velocity / max_turn_speed, -1.0, 1.0)
		last_angle = angle
		last_time = now

func _process(delta: float) -> void:
	# Smoothly approach target speed
	current_speed = lerp(current_speed, target_speed, clamp(acceleration * delta, 0, 1))

	# Apply rotation
	wheel.rotation += current_speed * max_turn_speed * delta

	# Emit signal
	wheel_rotated.emit(current_speed)

func reset_input() -> void:
	target_speed = 0.0
	current_speed = 0.0
	_process(0)
