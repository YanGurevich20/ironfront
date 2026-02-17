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


func assert_valid_for_tank(expected_tank_id: TankManager.TankId) -> void:
	assert(tank_id == expected_tank_id, "PlayerTankConfig tank_id mismatch")
	var shell_ids: Array[String] = ShellManager.get_shell_ids_for_tank(tank_id)
	assert(not shell_ids.is_empty(), "Tank has no registered shells: %s" % tank_id)
	var allowed_shell_specs: Dictionary[ShellSpec, bool] = {}
	for shell_id: String in shell_ids:
		var shell_spec: ShellSpec = ShellManager.get_shell_spec(shell_id)
		allowed_shell_specs[shell_spec] = true
	var total_shell_count: int = 0
	for shell_spec: ShellSpec in shell_amounts.keys():
		assert(allowed_shell_specs.has(shell_spec), "Shell not allowed for tank: %s" % shell_spec)
		var shell_count: int = int(shell_amounts[shell_spec])
		assert(shell_count >= 0, "Negative shell count: %s" % shell_count)
		total_shell_count += shell_count
	assert(total_shell_count > 0, "Tank has no ammunition")
	var tank_spec: TankSpec = TankManager.tank_specs[tank_id]
	assert(total_shell_count <= tank_spec.shell_capacity, "Shell capacity exceeded")


func build_shell_loadout_by_id() -> Dictionary:
	var shell_loadout_by_id: Dictionary = {}
	for shell_spec: ShellSpec in shell_amounts.keys():
		var shell_id: String = ShellManager.get_shell_id(shell_spec)
		shell_loadout_by_id[shell_id] = max(0, int(shell_amounts[shell_spec]))
	return shell_loadout_by_id


func pick_selected_shell_id(shell_loadout_by_id: Dictionary) -> String:
	for shell_id: String in ShellManager.get_shell_ids_for_tank(tank_id):
		var shell_count: int = max(0, int(shell_loadout_by_id.get(shell_id, 0)))
		if shell_count > 0:
			return shell_id
	return ""


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
