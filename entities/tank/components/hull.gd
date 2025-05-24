class_name Hull extends Sprite2D

@onready var tank :Tank= get_parent()
@onready var engine_sound :AudioStreamPlayer2D= %EngineSound

func play_engine_sound(_left_track_input: float, _right_track_input: float) -> void:
	engine_sound.pitch_scale = 1 #TODO: per speed and input

func animate_tracks(linear_velocity: Vector2, angular_velocity: float) -> void:
	var forward: Vector2 = tank.transform.x.normalized()
	var forward_velocity: Vector2 = linear_velocity.project(forward)
	var forward_sign: float = signf(forward.dot(linear_velocity))
	var base_speed: float = forward_velocity.length() * forward_sign

	var angular_contribution: float = angular_velocity * tank.tank_spec.track_offset.y
	var left_speed: float = base_speed + angular_contribution
	var right_speed: float = base_speed - angular_contribution

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
