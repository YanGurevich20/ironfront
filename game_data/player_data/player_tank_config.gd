class_name PlayerTankConfig extends Resource

@export var tank_id: TankManager.TankId
@export var shells: Dictionary[ShellManager.ShellId, int]

func unlock_shell(shell_id: ShellManager.ShellId) -> void:
	shells.set(shell_id, 0)

func get_shell_amount(shell_id: ShellManager.ShellId) -> int:
	assert(shell_id in shells, "Shell %s not found in shells" % shell_id)
	return shells.get(shell_id)

func set_shell_amount(shell_id: ShellManager.ShellId, amount: int) -> void:
	shells.set(shell_id, amount)
