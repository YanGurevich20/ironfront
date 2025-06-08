class_name Hull extends Sprite2D

@onready var tank :Tank= get_parent()
@onready var engine_sound :AudioStreamPlayer2D= %EngineSound
@onready var track_sound :AudioStreamPlayer2D= %TrackSound

const ENGINE_PITCH_MIN: float = 0.7
const ENGINE_PITCH_MAX: float = 1.8
const TRACK_PITCH_MIN: float = 0.5
const TRACK_PITCH_MAX: float = 1.5

func play_engine_sound(_left_track_input: float, _right_track_input: float, _linear_velocity: Vector2) -> void:
	var input_force: float= (abs(_left_track_input) + abs(_right_track_input)) / 2.0
	var target_pitch: float = lerp(ENGINE_PITCH_MIN, ENGINE_PITCH_MAX, input_force)
	engine_sound.pitch_scale = lerp(engine_sound.pitch_scale, target_pitch, 1 * get_physics_process_delta_time())

	var abs_speed:float = abs(tank.get_forward_speed(_linear_velocity))
	if abs_speed > 2.0:
		if not track_sound.is_playing(): track_sound.play()
		var speed_ratio: float = clamp(abs_speed / tank.tank_spec.max_speed, 0.0, 1.0)
		track_sound.pitch_scale = lerp(TRACK_PITCH_MIN, TRACK_PITCH_MAX, speed_ratio)
	else: track_sound.stop()

func animate_tracks(linear_velocity: Vector2, angular_velocity: float) -> void:
	var tank_speed: float = tank.get_forward_speed(linear_velocity)

	var angular_contribution: float = angular_velocity * tank.tank_spec.track_offset.y
	var left_speed: float = tank_speed + angular_contribution
	var right_speed: float = tank_speed - angular_contribution

	update_track_animation($LeftTrack, left_speed)
	update_track_animation($RightTrack, right_speed)

func update_track_animation(track_node: AnimatedSprite2D, speed: float) -> void:
	if abs(speed) > 0.01:
		track_node.play("default")
		track_node.flip_v = -speed < 0
		track_node.speed_scale = speed
	else:
		track_node.stop()
		track_node.speed_scale = 0.0

func stop_sounds() -> void:
	engine_sound.stop()
	track_sound.stop()
