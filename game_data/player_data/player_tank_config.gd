class_name PlayerTankConfig extends Resource

@export var tank_id: TankManager.TankId
@export var shell_amounts: Dictionary[ShellSpec, int]
@export var _is_initialized: bool = false


func _init(_tank_id: TankManager.TankId = tank_id) -> void:
	if _is_initialized:
		return
	tank_id = _tank_id
	var tank_spec: TankSpec = TankManager.tank_specs[tank_id]
	shell_amounts = {tank_spec.allowed_shells[0]: tank_spec.shell_capacity}
	_is_initialized = true


func unlock_shell(shell_spec: ShellSpec, initial_amount: int = 0) -> void:
	shell_amounts[shell_spec] = initial_amount


func get_shell_amount(shell_spec: ShellSpec) -> int:
	return shell_amounts.get(shell_spec, 0)


func set_shell_amount(shell_spec: ShellSpec, amount: int) -> void:
	shell_amounts[shell_spec] = amount


func get_total_shell_count() -> int:
	var total_count: int = 0
	for amount: int in shell_amounts.values():
		total_count += amount
	return total_count
