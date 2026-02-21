class_name Preferences 
extends Resource

const FILE_NAME: String = "preferences"

@export var selected_tank_id: String = TankManager.TANK_ID_M4A1_SHERMAN

func get_instance() -> Preferences:
	return DataStore.load_or_create(Preferences, FILE_NAME)

func save() -> void:
	DataStore.save(self, FILE_NAME)