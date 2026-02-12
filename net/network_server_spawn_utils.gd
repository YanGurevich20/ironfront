class_name NetworkServerSpawnUtils
extends RefCounted


static func pick_random_spawn(
	spawn_transforms_by_id: Dictionary[StringName, Transform2D]
) -> Dictionary:
	var available_spawn_ids: Array[StringName] = spawn_transforms_by_id.keys()
	if available_spawn_ids.is_empty():
		return {}
	available_spawn_ids.shuffle()
	var selected_spawn_id: StringName = available_spawn_ids[0]
	return {
		"spawn_id": selected_spawn_id,
		"spawn_transform": spawn_transforms_by_id[selected_spawn_id],
	}
