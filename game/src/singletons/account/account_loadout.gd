class_name AccountLoadout
extends RefCounted

signal selected_tank_id_updated(new_selected_tank_id: String)
signal tanks_updated(new_tanks: Dictionary[String, TankConfig])

var selected_tank_id: String = "":
	set(value):
		var next_selected_tank_id: String = value.strip_edges()
		if next_selected_tank_id == selected_tank_id:
			return
		selected_tank_id = next_selected_tank_id
		selected_tank_id_updated.emit(next_selected_tank_id)

var tanks: Dictionary[String, TankConfig] = {}:
	set(value):
		tanks = value
		tanks_updated.emit(tanks)


func has_tank(tank_id: String) -> bool:
	return tanks.has(tank_id)


func get_tank_ids() -> Array[String]:
	var tank_ids: Array[String] = []
	for tank_id_variant: Variant in tanks.keys():
		var tank_id: String = str(tank_id_variant)
		if tank_id.is_empty():
			continue
		tank_ids.append(tank_id)
	return tank_ids


func get_tank_config(tank_id: String) -> TankConfig:
	return tanks.get(tank_id, null)


func get_selected_tank_config() -> TankConfig:
	return tanks.get(selected_tank_id, null)


func unlock_tank(tank_id: String) -> bool:
	if tanks.has(tank_id):
		return false
	var tank_spec: TankSpec = TankManager.tank_specs.get(tank_id, null)
	if tank_spec == null:
		push_warning("AccountLoadout: missing tank spec for tank_id=%s" % tank_id)
		return false
	var shell_ids: Array[String] = ShellManager.get_shell_ids_for_tank(tank_id)
	if shell_ids.is_empty():
		push_warning("AccountLoadout: no shells for tank_id=%s" % tank_id)
		return false
	var first_shell_id: String = shell_ids[0]
	var cfg: TankConfig = TankConfig.new()
	cfg.tank_id = tank_id
	cfg.unlocked_shell_ids = [first_shell_id]
	cfg.shell_loadout_by_id = {first_shell_id: tank_spec.shell_capacity}
	var next_tanks: Dictionary[String, TankConfig] = {}
	for k: String in tanks.keys():
		next_tanks[k] = tanks[k]
	next_tanks[tank_id] = cfg
	tanks = next_tanks
	if selected_tank_id.is_empty():
		selected_tank_id = tank_id
	return true
