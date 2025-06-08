class_name ShellManager

enum ShellId {
	M63,
	M63_T,
	M75,
	M75_T,
	M82,
	PZGR39,
	PZGR39_T,
	PZGR40,
	DEBUG_AP,
	DEBUG_AP_T,
	DEBUG_HE,
	DEBUG_HEAT,
	DEBUG_APCR,
	DEBUG_APHE,
	DEBUG_APDS,
}

static var SHELL_SPECS: Dictionary[ShellId, ShellSpec] = {
	ShellId.M63: preload("res://entities/shell/shells/m63.tres"),
	ShellId.M63_T: preload("res://entities/shell/shells/m63_t.tres"),
	ShellId.M75: preload("res://entities/shell/shells/m75.tres"),
	ShellId.M75_T: preload("res://entities/shell/shells/m75_t.tres"),
	ShellId.M82: preload("res://entities/shell/shells/m82.tres"),
	ShellId.PZGR39: preload("res://entities/shell/shells/pzgr39.tres"),
	ShellId.PZGR39_T: preload("res://entities/shell/shells/pzgr39_t.tres"),
	ShellId.PZGR40: preload("res://entities/shell/shells/pzgr40.tres"),
	ShellId.DEBUG_AP: preload("res://entities/shell/shells/debug_shells/debug_ap.tres"),
	ShellId.DEBUG_AP_T: preload("res://entities/shell/shells/debug_shells/debug_ap_t.tres"),
	ShellId.DEBUG_HE: preload("res://entities/shell/shells/debug_shells/debug_he.tres"),
	ShellId.DEBUG_HEAT: preload("res://entities/shell/shells/debug_shells/debug_heat.tres"),
	ShellId.DEBUG_APCR: preload("res://entities/shell/shells/debug_shells/debug_apcr.tres"),
	ShellId.DEBUG_APHE: preload("res://entities/shell/shells/debug_shells/debug_aphe.tres"),
	ShellId.DEBUG_APDS: preload("res://entities/shell/shells/debug_shells/debug_apds.tres"),
}
