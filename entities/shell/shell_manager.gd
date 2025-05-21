class_name ShellManager

enum ShellId {
	M63,
	M63_T,
	M75,
	M75_T,
	PZGR39,
	PZGR39_T	
}

static var SHELL_SPECS: Dictionary[ShellId, ShellSpec] = {
	ShellId.M63: preload("res://entities/shell/shells/m63.tres"),
	ShellId.M63_T: preload("res://entities/shell/shells/m63_t.tres"),
	ShellId.M75: preload("res://entities/shell/shells/m75.tres"),
	ShellId.M75_T: preload("res://entities/shell/shells/m75_t.tres"),
	ShellId.PZGR39: preload("res://entities/shell/shells/pzgr39.tres"),
	ShellId.PZGR39_T: preload("res://entities/shell/shells/pzgr39_t.tres"),
}

static func get_shell_spec(shell_id: ShellId) -> ShellSpec:
	return SHELL_SPECS.get(shell_id)
