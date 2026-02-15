class_name MultiplayerTankController
extends Node

@onready var tank: Tank = get_parent()


func _ready() -> void:
	Utils.connect_checked(GameplayBus.lever_input, _on_lever_input)
	Utils.connect_checked(GameplayBus.wheel_input, _on_wheel_input)
	Utils.connect_checked(
		GameplayBus.update_remaining_shell_count, _on_update_remaining_shell_count
	)


func _on_lever_input(lever_side: Lever.LeverSide, value: float) -> void:
	if lever_side == Lever.LeverSide.LEFT:
		tank.left_track_input = value
	elif lever_side == Lever.LeverSide.RIGHT:
		tank.right_track_input = value


func _on_wheel_input(value: float) -> void:
	tank.turret_rotation_input = value


func _on_update_remaining_shell_count(count: int) -> void:
	tank.set_remaining_shell_count(count)
