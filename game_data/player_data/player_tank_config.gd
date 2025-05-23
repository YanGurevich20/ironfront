class_name PlayerTankConfig extends Resource

@export var tank_id: TankManager.TankId
@export var shells: Dictionary[ShellManager.ShellId, int]

func unlock_shell(shell_id: ShellManager.ShellId) -> void:
	shells.set(shell_id, 0)

func get_shell_amount(shell_id: ShellManager.ShellId) -> int:
	check_and_fix_shells_integrity()
	assert(shell_id in shells, "Shell %s not found in shells" % shell_id)
	return shells.get(shell_id)

func set_shell_amount(shell_id: ShellManager.ShellId, amount: int) -> void:
	shells.set(shell_id, amount)

func check_and_fix_shells_integrity() -> void:
	var tank_spec: TankSpec = TankManager.get_tank_spec(tank_id)
	for shell_id: ShellManager.ShellId in shells.keys():
		if shell_id not in tank_spec.allowed_shells:
			shells.erase(shell_id)
