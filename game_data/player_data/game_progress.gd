class_name GameProgress extends Resource

@export var stars_per_level: Dictionary[int, int] = {} # e.g. {1: 3} means 3 stars on level 1

const GAME_PROGRESS_PATH = "user://game_progress.tres"

func update_progress(level: int, stars: int) -> void:
	var previous_stars :int= stars_per_level.get(level, 0)
	if stars >= previous_stars:
		stars_per_level[level] = stars

func get_stars_for_level(level: int) -> int:
	return stars_per_level.get(level, 0)

func save() -> void:
	ResourceSaver.save(self, GAME_PROGRESS_PATH)

func reset() -> void:
	stars_per_level = {}

static func load_or_create() -> GameProgress:
	if ResourceLoader.exists(GAME_PROGRESS_PATH):
		var loaded :GameProgress= load(GAME_PROGRESS_PATH)
		if loaded is GameProgress:
			return loaded
	var new_progress := GameProgress.new()
	new_progress.save()
	return new_progress
