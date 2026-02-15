class_name PlayerData extends Resource

const DEFAULT_TANK_ID: TankManager.TankId = TankManager.TankId.M4A1_SHERMAN
const FILE_NAME: String = "player_data"

@export var player_name: String = "Player"
@export var stars_per_level: Dictionary[int, int] = {}
@export var dollars: int = 300_000
@export var bonds: int = 0
@export var tank_configs: Dictionary[TankManager.TankId, PlayerTankConfig] = {}
@export var selected_tank_id: TankManager.TankId
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


func update_progress(level: int, stars: int, dollars_earned: int) -> void:
	var previous_stars: int = stars_per_level.get(level, 0)
	if stars >= previous_stars:
		stars_per_level[level] = stars
	add_dollars(dollars_earned)


func get_stars_for_level(level: int) -> int:
	return stars_per_level.get(level, 0)


func get_unlocked_tank_ids() -> Array[TankManager.TankId]:
	var unlocked_tank_ids: Array[TankManager.TankId] = []
	for id: TankManager.TankId in tank_configs.keys():
		unlocked_tank_ids.append(id)
	return unlocked_tank_ids


func get_tank_config(tank_id: TankManager.TankId) -> PlayerTankConfig:
	return tank_configs[tank_id]


func get_current_tank_config() -> PlayerTankConfig:
	return get_tank_config(selected_tank_id)


func unlock_tank(tank_id: TankManager.TankId) -> void:
	if tank_configs.has(tank_id):
		push_warning("Tank already unlocked: ", tank_id)
		return
	var tank_config: PlayerTankConfig = PlayerTankConfig.new(tank_id)
	tank_configs[tank_id] = tank_config
	selected_tank_id = tank_id


func is_selected_tank_valid() -> bool:
	return selected_tank_id in tank_configs.keys()
