extends Node

@onready var tank :Tank= get_parent()

func gather_inputs() -> Dictionary:
	return {
		"left_track": Input.get_action_strength("track_left_forward") - Input.get_action_strength("track_left_backward"),
		"right_track": Input.get_action_strength("track_right_forward") - Input.get_action_strength("track_right_backward"),
		"turret": Input.get_action_strength("turret_right") - Input.get_action_strength("turret_left"),
		"fire": Input.is_action_just_pressed("fire_shell")
	}

func _physics_process(_delta: float) -> void:
	var inputs := gather_inputs()
	tank.left_track_input = inputs.left_track
	tank.right_track_input = inputs.right_track
	tank.turret_rotation_input = inputs.turret
	if inputs.fire:
		tank.fire_shell()
