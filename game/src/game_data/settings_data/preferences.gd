class_name Preferences
extends Resource

signal selected_tank_id_updated(new_selected_tank_id: String)

const FILE_NAME: String = "preferences"

@export var selected_tank_id: String = TankManager.TANK_ID_M4A1_SHERMAN:
	set(value):
		selected_tank_id = value
		selected_tank_id_updated.emit(value)


static func get_instance() -> Preferences:
	return DataStore.load_or_create(Preferences, FILE_NAME)


func save() -> void:
	DataStore.save(self, FILE_NAME)
