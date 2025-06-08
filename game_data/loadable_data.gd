class_name LoadableData
extends Resource

static var _instances: Dictionary = {}

static func get_loadable_instance(cls: GDScript) -> LoadableData:
	var instance: LoadableData = cls.new()
	var key: String = instance.get_file_name()

	if _instances.has(key):
		return _instances[key]

	var path: String = instance._get_path()

	if ResourceLoader.exists(path):
		instance = load(path)
	else:
		instance.save()

	_instances[key] = instance
	return instance

static func reset(cls: GDScript) -> void:
	var instance: LoadableData = cls.new()
	var key: String = instance.get_file_name()
	_instances.erase(key)

	var path: String = instance._get_path()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

func get_file_name() -> String:
	push_error("Subclasses must override get_file_name()")
	return ""

func _get_path() -> String:
	return "user://%s.tres" % get_file_name()

func save() -> void:
	var path := _get_path()
	var result := ResourceSaver.save(self, path)
	if result != OK:
		push_error("Failed to save %s" % path)

func print_properties() -> void:
	Utils.print_resource_properties(self)