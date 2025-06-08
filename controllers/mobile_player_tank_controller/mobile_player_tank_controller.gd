extends Node
@onready var tank: Tank = get_parent()

func _on_lever_input(lever_side: Lever.LeverSide, value: float) -> void:
	if tank.is_player:
		if lever_side == Lever.LeverSide.LEFT:
			tank.left_track_input = value
		elif lever_side == Lever.LeverSide.RIGHT:
			tank.right_track_input = value

func _on_wheel_input(value:float) -> void:
	if tank.is_player:
		tank.turret_rotation_input = value

func _on_fire_input() -> void:
	if tank.is_player:
		tank.fire_shell()

func _on_shell_selected(shell_id: ShellManager.ShellId, remaining_shell_count: int) -> void:
	if tank.is_player:
		tank.set_current_shell_id(shell_id)
		tank.set_remaining_shell_count(remaining_shell_count)

func _on_update_remaining_shell_count(count: int) -> void:
	if tank.is_player:
		tank.set_remaining_shell_count(count)

func _enter_tree() -> void:
	SignalBus.lever_input.connect(_on_lever_input)
	SignalBus.wheel_input.connect(_on_wheel_input) 
	SignalBus.fire_input.connect(_on_fire_input)
	SignalBus.shell_selected.connect(_on_shell_selected)
	SignalBus.update_remaining_shell_count.connect(_on_update_remaining_shell_count)

func _exit_tree() -> void:
	if SignalBus.lever_input.is_connected(_on_lever_input):
		SignalBus.lever_input.disconnect(_on_lever_input)
	if SignalBus.wheel_input.is_connected(_on_wheel_input):
		SignalBus.wheel_input.disconnect(_on_wheel_input)
	if SignalBus.fire_input.is_connected(_on_fire_input):
		SignalBus.fire_input.disconnect(_on_fire_input)
	if SignalBus.shell_selected.is_connected(_on_shell_selected):
		SignalBus.shell_selected.disconnect(_on_shell_selected)

