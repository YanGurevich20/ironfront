class_name ArenaLevelMvp
extends Node2D

@onready var arena_spawn_points: Node2D = %ArenaSpawnPoints


func get_spawn_markers() -> Array[Marker2D]:
	var markers: Array[Marker2D] = []
	for child: Node in arena_spawn_points.get_children():
		var spawn_marker: Marker2D = child as Marker2D
		if spawn_marker == null:
			continue
		markers.append(spawn_marker)
	markers.sort_custom(
		func(marker_a: Marker2D, marker_b: Marker2D) -> bool:
			return str(_resolve_marker_spawn_id(marker_a)) < str(_resolve_marker_spawn_id(marker_b))
	)
	return markers


func validate_spawn_markers() -> Dictionary:
	var markers: Array[Marker2D] = get_spawn_markers()
	var used_spawn_ids: Dictionary = {}
	var duplicate_spawn_ids: PackedStringArray = []
	var empty_spawn_id_count: int = 0

	for marker: Marker2D in markers:
		var marker_spawn_id: String = str(_resolve_marker_spawn_id(marker))
		if marker_spawn_id.is_empty():
			empty_spawn_id_count += 1
			continue
		if used_spawn_ids.has(marker_spawn_id):
			duplicate_spawn_ids.append(marker_spawn_id)
			continue
		used_spawn_ids[marker_spawn_id] = true

	return {
		"valid":
		empty_spawn_id_count == 0 and duplicate_spawn_ids.is_empty() and markers.size() > 0,
		"spawn_count": markers.size(),
		"empty_spawn_id_count": empty_spawn_id_count,
		"duplicate_spawn_ids": duplicate_spawn_ids,
	}


func get_spawn_transforms_by_id() -> Dictionary[StringName, Transform2D]:
	var spawn_transforms_by_id: Dictionary[StringName, Transform2D] = {}
	for marker: Marker2D in get_spawn_markers():
		var marker_spawn_id: StringName = _resolve_marker_spawn_id(marker)
		if marker_spawn_id == StringName():
			continue
		spawn_transforms_by_id[marker_spawn_id] = marker.global_transform
	return spawn_transforms_by_id


func _resolve_marker_spawn_id(marker: Marker2D) -> StringName:
	var property_spawn_id: Variant = marker.get("spawn_id")
	if property_spawn_id is StringName:
		var typed_spawn_id: StringName = property_spawn_id
		return typed_spawn_id
	return StringName()
