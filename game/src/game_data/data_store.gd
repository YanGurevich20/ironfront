class_name DataStore
extends RefCounted


static func build_path(file_name: String) -> String:
	return "user://%s.tres" % file_name


static func load_or_create(cls: GDScript, file_name: String) -> Resource:
	var instance: Resource = cls.new()
	var path: String = build_path(file_name)

	if ResourceLoader.exists(path):
		var loaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE)
		if loaded == null:
			push_warning("Failed to load %s, recreating resource." % path)
			save(instance, file_name)
		else:
			instance = loaded as Resource
	else:
		save(instance, file_name)

	return instance


static func save(resource: Resource, file_name: String) -> void:
	var path: String = build_path(file_name)
	var result := ResourceSaver.save(resource, path)
	if result != OK:
		push_error("Failed to save %s" % path)


static func reset(cls: GDScript, file_name: String) -> void:
	push_warning("Resetting %s" % cls, "Unsafe method!")
	var path: String = build_path(file_name)
	if FileAccess.file_exists(path):
		var remove_result := DirAccess.remove_absolute(path)
		if remove_result != OK:
			push_warning("Failed to remove data file: ", path)
	var fresh: Resource = cls.new()
	save(fresh, file_name)
