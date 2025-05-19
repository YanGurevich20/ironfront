class_name PlayerData extends LoadableData

@export var player_name: String = ""
@export var stars_per_level: Dictionary[int, int] = {}
@export var dollars: int = 0
@export var bonds: int = 0
@export var unlocked_tank_ids: Array[TankManager.TankId] = []
@export var selected_tank_id: TankManager.TankId = TankManager.TankId.m4a1_sherman

const FILE_NAME: String = "player_data"

func get_file_name() -> String:
	return FILE_NAME

func add_dollars(amount: int) -> void:
	dollars += amount

func update_progress(level: int, stars: int, dollars_earned: int) -> void:
	var previous_stars: int = stars_per_level.get(level, 0)
	if stars >= previous_stars:
		stars_per_level[level] = stars
	add_dollars(dollars_earned)

func get_stars_for_level(level: int) -> int:
	return stars_per_level.get(level, 0)