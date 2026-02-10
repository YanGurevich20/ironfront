class_name SettingsData extends LoadableData

const FILE_NAME: String = "settings_data"

@export_group("Audio")
@export_range(0.0, 1.0, 0.05) var master_volume: float = 1.0:
	set(value):
		master_volume = value
		var bus_index := AudioServer.get_bus_index("Master")
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(value))
		save()
		GameplayBus.settings_changed.emit()

@export_group("HUD")
@export_range(0.0, 1.0, 0.05) var controls_opacity: float = 0.8:
	set(value):
		controls_opacity = value
		save()
		GameplayBus.settings_changed.emit()

@export_range(0.0, 1.0, 0.05) var tank_hud_opacity: float = 0.8:
	set(value):
		tank_hud_opacity = value
		save()
		GameplayBus.settings_changed.emit()

# settings that are not controlled from the settings menu
@export_group("Dynamic")
@export_range(0.5, 1.5, 0.1) var zoom_level: float = 1.0:
	set(value):
		zoom_level = value
		save()
		GameplayBus.settings_changed.emit()


func get_file_name() -> String:
	return FILE_NAME


static func get_instance() -> SettingsData:
	return LoadableData.get_loadable_instance(SettingsData)
