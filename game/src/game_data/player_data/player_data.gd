class_name PlayerData extends Resource

const DEFAULT_TANK_ID: String = TankManager.TANK_ID_M4A1_SHERMAN
const FILE_NAME: String = "player_data_v2"

@export var player_name: String = "Player"
@export var dollars: int = 300_000
@export var bonds: int = 0
@export var tank_configs: Dictionary[String, PlayerTankConfig] = {}
@export var selected_tank_id: String
@export var is_developer: bool = false


static func get_instance() -> PlayerData:
	return DataStore.load_or_create(PlayerData, FILE_NAME)


func save() -> void:
	DataStore.save(self, FILE_NAME)


func _init() -> void:
	if tank_configs.is_empty():
		unlock_tank(DEFAULT_TANK_ID)


func add_dollars(amount: int) -> void:
	dollars += amount


func get_unlocked_tank_ids() -> Array[String]:
	var unlocked_tank_ids: Array[String] = []
	for tank_id: String in tank_configs.keys():
		unlocked_tank_ids.append(tank_id)
	return unlocked_tank_ids


func get_tank_config(tank_id: String) -> PlayerTankConfig:
	return tank_configs[tank_id]


func get_current_tank_config() -> PlayerTankConfig:
	return get_tank_config(selected_tank_id)


func unlock_tank(tank_id: String) -> void:
	if tank_configs.has(tank_id):
		push_warning("Tank already unlocked: ", tank_id)
		return
	var tank_config: PlayerTankConfig = PlayerTankConfig.new(tank_id)
	tank_configs[tank_id] = tank_config
	selected_tank_id = tank_id


func is_selected_tank_valid() -> bool:
	return selected_tank_id in tank_configs.keys()


func build_join_arena_payload() -> Dictionary:
	assert(is_selected_tank_valid(), "Invalid selected tank_id: %s" % selected_tank_id)
	var tank_config: PlayerTankConfig = get_current_tank_config()
	tank_config.assert_valid_for_tank(selected_tank_id)
	var shell_loadout_by_id: Dictionary = tank_config.build_shell_loadout_by_id()
	var selected_shell_id: String = tank_config.pick_selected_shell_id(shell_loadout_by_id)
	assert(
		not selected_shell_id.is_empty(), "No usable shell for tank_id: %s" % tank_config.tank_id
	)
	return {
		"tank_id": tank_config.tank_id,
		"shell_loadout_by_id": shell_loadout_by_id,
		"selected_shell_id": selected_shell_id,
	}
