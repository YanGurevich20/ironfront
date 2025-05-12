extends Node
@onready var tank: Tank = get_parent()

func _on_lever_input(lever_side: Lever.Side, value: float) -> void:
	if tank.is_player: # Ensure this controller only acts if it's the player's tank
		if lever_side == Lever.Side.LEFT:
			tank.left_track_input = value
		elif lever_side == Lever.Side.RIGHT:
			tank.right_track_input = value

func _on_wheel_input(value:float) -> void:
	if tank.is_player: # Ensure this controller only acts if it's the player's tank
		tank.turret_rotation_input = value

func _on_fire_input() -> void:
	if tank.is_player: # Ensure this controller only acts if it's the player's tank
		tank.fire_shell()

func _enter_tree() -> void:
	SignalBus.lever_input.connect(_on_lever_input)
	SignalBus.wheel_input.connect(_on_wheel_input) 
	SignalBus.fire_input.connect(_on_fire_input)

func _exit_tree() -> void:
	if SignalBus.lever_input.is_connected(_on_lever_input):
		SignalBus.lever_input.disconnect(_on_lever_input)
	if SignalBus.wheel_input.is_connected(_on_wheel_input):
		SignalBus.wheel_input.disconnect(_on_wheel_input)
	if SignalBus.fire_input.is_connected(_on_fire_input):
		SignalBus.fire_input.disconnect(_on_fire_input)
