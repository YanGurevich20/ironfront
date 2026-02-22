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
