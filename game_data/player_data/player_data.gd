class_name PlayerData extends LoadableData

@export var player_name: String = ""
@export var stars_per_level: Dictionary[int, int] = {}
@export var dollars: int = 20_000
@export var bonds: int = 0
@export var tank_configs: Dictionary[TankManager.TankId, PlayerTankConfig]
@export var selected_tank_id: TankManager.TankId

const FILE_NAME: String = "player_data"

func get_file_name() -> String:
	return FILE_NAME

static func get_instance() -> PlayerData:
	return LoadableData.get_loadable_instance(PlayerData)

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
	var tank_config: PlayerTankConfig = PlayerTankConfig.new()
	tank_config.tank_id = tank_id
	tank_configs.set(tank_id, tank_config)

func is_selected_tank_valid() -> bool:
	return selected_tank_id in tank_configs.keys()
