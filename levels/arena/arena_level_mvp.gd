class_name ArenaLevelMvp
extends Node2D

const ArenaSpawnMarker = preload("res://levels/arena/arena_spawn_marker.gd")

@onready var arena_spawn_points: Node2D = %ArenaSpawnPoints


func get_spawn_markers() -> Array[ArenaSpawnMarker]:
	var markers: Array[ArenaSpawnMarker] = []
	for child: Node in arena_spawn_points.get_children():
		var spawn_marker: ArenaSpawnMarker = child as ArenaSpawnMarker
		if spawn_marker == null:
			continue
		markers.append(spawn_marker)
	markers.sort_custom(
		func(marker_a: ArenaSpawnMarker, marker_b: ArenaSpawnMarker) -> bool:
			return str(marker_a.spawn_id) < str(marker_b.spawn_id)
	)
	return markers


func validate_spawn_markers() -> Dictionary:
	var markers: Array[ArenaSpawnMarker] = get_spawn_markers()
	var used_spawn_ids: Dictionary = {}
	var duplicate_spawn_ids: PackedStringArray = []
	var empty_spawn_id_count: int = 0

	for marker: ArenaSpawnMarker in markers:
		var marker_spawn_id: String = str(marker.spawn_id)
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


func get_spawn_transforms_by_id() -> Dictionary:
	var spawn_transforms_by_id: Dictionary = {}
	for marker: ArenaSpawnMarker in get_spawn_markers():
		if marker.spawn_id == StringName():
			continue
		spawn_transforms_by_id[marker.spawn_id] = marker.global_transform
	return spawn_transforms_by_id
