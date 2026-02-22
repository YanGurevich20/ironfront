class_name AccountLoadout
extends RefCounted

signal selected_tank_spec_updated(new_selected_tank_spec: TankSpec)
signal tanks_updated(new_tanks: Dictionary[TankSpec, TankConfig])

var selected_tank_spec: TankSpec:
	get:
		if _selected_tank_spec != null:
			return _selected_tank_spec
		return _first_unlocked_tank_spec_or_default()
	set(value):
		var effective_new: TankSpec = _coerce_selected_tank_spec(value)
		var effective_old: TankSpec = (
			_selected_tank_spec
			if _selected_tank_spec != null
			else _first_unlocked_tank_spec_or_default()
		)
		if effective_new == effective_old:
			return
		_selected_tank_spec = effective_new
		selected_tank_spec_updated.emit(effective_new)

var tanks: Dictionary[TankSpec, TankConfig] = {}:
	set(value):
		tanks = value
		_selected_tank_spec = _coerce_selected_tank_spec(_selected_tank_spec)
		tanks_updated.emit(tanks)

var _selected_tank_spec: TankSpec = null


static func _default_tank_spec() -> TankSpec:
	return TankManager.require_tank_spec(TankManager.TANK_ID_M4A1_SHERMAN)


func _first_unlocked_tank_spec_or_default() -> TankSpec:
	for key: Variant in tanks.keys():
		var spec: TankSpec = key as TankSpec
		if spec != null:
			return spec
	return _default_tank_spec()


func _coerce_selected_tank_spec(candidate: TankSpec) -> TankSpec:
	if candidate != null and (tanks.is_empty() or tanks.has(candidate)):
		return candidate
	return _first_unlocked_tank_spec_or_default()


static func _spec_with_shells() -> TankSpec:
	var default_spec: TankSpec = _default_tank_spec()
	if default_spec != null and not default_spec.allowed_shells.is_empty():
		return default_spec
	for tank_id: String in TankManager.get_tank_ids():
		var s: TankSpec = TankManager.find_tank_spec(tank_id)
		if s != null and not s.allowed_shells.is_empty():
			return s
	return _default_tank_spec()


func has_tank(tank_spec: TankSpec) -> bool:
	return tanks.has(tank_spec)


func get_tank_specs() -> Array[TankSpec]:
	var result: Array[TankSpec] = []
	for key: Variant in tanks.keys():
		if key is TankSpec:
			result.append(key)
	return result


func get_tank_config(tank_spec: TankSpec) -> TankConfig:
	return tanks.get(tank_spec, null)


func get_selected_tank_config() -> TankConfig:
	if tanks.has(selected_tank_spec):
		return tanks.get(selected_tank_spec)
	_repair_selected_tank_in_tanks()
	return tanks.get(selected_tank_spec)


func _repair_selected_tank_in_tanks() -> void:
	var spec: TankSpec = selected_tank_spec
	if spec != null and spec.allowed_shells.is_empty():
		push_warning("AccountLoadout: selected tank has no allowed_shells, falling back to default")
		spec = _spec_with_shells()
		_selected_tank_spec = spec
		selected_tank_spec_updated.emit(spec)
	if spec == null:
		spec = _default_tank_spec()
	var cfg: TankConfig = TankConfig.new()
	cfg.tank_spec = spec
	if not spec.allowed_shells.is_empty():
		var first_shell: ShellSpec = spec.allowed_shells[0]
		cfg.unlocked_shell_specs = [first_shell]
		var shell_loadout_by_spec: Dictionary[ShellSpec, int] = {}
		shell_loadout_by_spec[first_shell] = spec.shell_capacity
		cfg.shell_loadout_by_spec = shell_loadout_by_spec
	var next_tanks: Dictionary[TankSpec, TankConfig] = {}
	for k in tanks:
		next_tanks[k] = tanks[k]
	next_tanks[spec] = cfg
	tanks = next_tanks


func unlock_tank(tank_spec: TankSpec) -> bool:
	if tanks.has(tank_spec):
		return false
	if tank_spec.allowed_shells.is_empty():
		push_warning("AccountLoadout: no shells for tank_spec=%s" % tank_spec.tank_id)
		return false
	var first_shell: ShellSpec = tank_spec.allowed_shells[0]
	var cfg: TankConfig = TankConfig.new()
	cfg.tank_spec = tank_spec
	cfg.unlocked_shell_specs = [first_shell]
	var shell_loadout_by_spec: Dictionary[ShellSpec, int] = {}
	shell_loadout_by_spec[first_shell] = tank_spec.shell_capacity
	cfg.shell_loadout_by_spec = shell_loadout_by_spec
	var next_tanks: Dictionary[TankSpec, TankConfig] = {}
	for k in tanks:
		next_tanks[k] = tanks[k]
	next_tanks[tank_spec] = cfg
	tanks = next_tanks
	if next_tanks.size() == 1:
		selected_tank_spec = tank_spec
	return true


func to_join_arena_payload() -> Dictionary:
	var selected_spec: TankSpec = selected_tank_spec
	assert(selected_spec != null, "AccountLoadout: selected_tank_spec is null for join payload")
	var tank_config: TankConfig = get_selected_tank_config()
	var shell_loadout_by_id: Dictionary = {}
	for shell_spec_key: Variant in tank_config.shell_loadout_by_spec.keys():
		var shell_spec: ShellSpec = shell_spec_key as ShellSpec
		if shell_spec == null:
			continue
		var shell_id: String = ShellManager.get_shell_id(shell_spec)
		shell_loadout_by_id[shell_id] = int(tank_config.shell_loadout_by_spec[shell_spec_key])
	var selected_shell_id: String = ""
	for shell_spec: ShellSpec in selected_spec.allowed_shells:
		var shell_id: String = ShellManager.get_shell_id(shell_spec)
		var shell_count: int = int(shell_loadout_by_id.get(shell_id, 0))
		if shell_count > 0:
			selected_shell_id = shell_id
			break
	return {
		"tank_id": selected_spec.tank_id,
		"shell_loadout_by_id": shell_loadout_by_id,
		"selected_shell_id": selected_shell_id,
	}
