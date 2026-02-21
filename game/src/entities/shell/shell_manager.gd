class_name ShellManager

static var shell_specs_by_id: Dictionary[String, ShellSpec] = {}
static var shell_ids_by_tank_id: Dictionary[String, Array] = {}
static var initialized: bool = false


static func get_shell_spec(shell_id: String) -> ShellSpec:
	_ensure_initialized()
	if not shell_specs_by_id.has(shell_id):
		return null
	return shell_specs_by_id[shell_id]


static func has_shell_id(shell_id: String) -> bool:
	_ensure_initialized()
	return shell_specs_by_id.has(shell_id)


static func get_shell_id(shell_spec: ShellSpec) -> String:
	return str(shell_spec.shell_id)


static func get_shell_ids_for_tank(tank_id: String) -> Array[String]:
	_ensure_initialized()
	if not shell_ids_by_tank_id.has(tank_id):
		return []
	var shell_ids: Array = shell_ids_by_tank_id[tank_id]
	return Array(shell_ids, TYPE_STRING, "", null)


static func _ensure_initialized() -> void:
	if initialized:
		return
	shell_specs_by_id.clear()
	shell_ids_by_tank_id.clear()
	for tank_id: String in TankManager.tank_specs.keys():
		var tank_spec: TankSpec = TankManager.tank_specs.get(tank_id)
		assert(tank_spec != null, "ShellManager: tank spec missing for tank_id=%s" % tank_id)
		var shell_ids: Array[String] = []
		for shell_spec: ShellSpec in tank_spec.allowed_shells:
			assert(
				shell_spec != null,
				"ShellManager: null shell in allowed_shells tank_id=%s" % tank_id
			)
			var shell_id: String = str(shell_spec.shell_id)
			assert(
				not shell_id.is_empty(),
				"ShellManager: shell_id is empty in tank_id=%s shell=%s" % [tank_id, shell_spec]
			)
			assert(
				not shell_specs_by_id.has(shell_id),
				"ShellManager: duplicate shell_id=%s" % shell_id
			)
			shell_specs_by_id[shell_id] = shell_spec
			shell_ids.append(shell_id)
		shell_ids_by_tank_id[tank_id] = shell_ids
	initialized = true
