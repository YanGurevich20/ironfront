class_name SettingsData extends LoadableData

@export_group("HUD")
@export var controls_opacity: float = 0.8:
	set(value):
		controls_opacity = value
		save()
		SignalBus.settings_changed.emit()

@export var tank_hud_opacity: float = 0.8:
	set(value):
		tank_hud_opacity = value
		save()
		SignalBus.settings_changed.emit()

# settings that are not controlled from the settings menu
@export_group("Dynamic")
@export var zoom_level: float = 1.0:
	set(value):
		print("zoom_level set to ", value)
		zoom_level = value
		save()
		SignalBus.settings_changed.emit()

const FILE_NAME: String = "settings_data"

func get_file_name() -> String:
	return FILE_NAME

static func get_instance() -> SettingsData:
	return LoadableData.get_loadable_instance(SettingsData)
