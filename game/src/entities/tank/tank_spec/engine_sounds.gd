class_name EngineSounds extends Resource

const TANK_SIZE_CLASS = Enums.TankSizeClass
const SPEED_TYPE = Enums.SpeedType

const SMALL_ENGINE_SOUNDS: Dictionary[SPEED_TYPE, AudioStream] = {
	SPEED_TYPE.SLOW:
	preload("res://src/entities/tank/shared_assets/sounds/engine/small/engine_small_slow.ogg"),
	SPEED_TYPE.NORMAL:
	preload("res://src/entities/tank/shared_assets/sounds/engine/small/engine_small_normal.ogg"),
	SPEED_TYPE.FAST:
	preload("res://src/entities/tank/shared_assets/sounds/engine/small/engine_small_fast.ogg")
}
const MEDIUM_ENGINE_SOUNDS: Dictionary[SPEED_TYPE, AudioStream] = {
	SPEED_TYPE.SLOW:
	preload("res://src/entities/tank/shared_assets/sounds/engine/medium/engine_medium_slow.ogg"),
	SPEED_TYPE.NORMAL:
	preload("res://src/entities/tank/shared_assets/sounds/engine/medium/engine_medium_normal.ogg"),
	SPEED_TYPE.FAST:
	preload("res://src/entities/tank/shared_assets/sounds/engine/medium/engine_medium_fast.ogg")
}
const LARGE_ENGINE_SOUNDS: Dictionary[SPEED_TYPE, AudioStream] = {
	SPEED_TYPE.SLOW:
	preload("res://src/entities/tank/shared_assets/sounds/engine/large/engine_large_slow.ogg"),
	SPEED_TYPE.NORMAL:
	preload("res://src/entities/tank/shared_assets/sounds/engine/large/engine_large_normal.ogg"),
	SPEED_TYPE.FAST:
	preload("res://src/entities/tank/shared_assets/sounds/engine/large/engine_large_fast.ogg")
}

const ENGINE_SOUNDS: Dictionary[TANK_SIZE_CLASS, Dictionary] = {
	TANK_SIZE_CLASS.SMALL: SMALL_ENGINE_SOUNDS,
	TANK_SIZE_CLASS.MEDIUM: MEDIUM_ENGINE_SOUNDS,
	TANK_SIZE_CLASS.LARGE: LARGE_ENGINE_SOUNDS
}

#TODO: Adjust pitch ranges based on engine size and speed type
const SMALL_ENGINE_PITCH_RANGES: Dictionary[SPEED_TYPE, Vector2] = {
	SPEED_TYPE.SLOW: Vector2(0.8, 1.2),
	SPEED_TYPE.NORMAL: Vector2(0.7, 1.5),
	SPEED_TYPE.FAST: Vector2(0.9, 1.3)
}
const MEDIUM_ENGINE_PITCH_RANGES: Dictionary[SPEED_TYPE, Vector2] = {
	SPEED_TYPE.SLOW: Vector2(0.8, 1.2),
	SPEED_TYPE.NORMAL: Vector2(0.7, 1.5),
	SPEED_TYPE.FAST: Vector2(0.9, 1.3)
}
const LARGE_ENGINE_PITCH_RANGES: Dictionary[SPEED_TYPE, Vector2] = {
	SPEED_TYPE.SLOW: Vector2(0.8, 1.2),
	SPEED_TYPE.NORMAL: Vector2(0.7, 1.5),
	SPEED_TYPE.FAST: Vector2(0.9, 1.3)
}

const ENGINE_PITCH_RANGES: Dictionary[TANK_SIZE_CLASS, Dictionary] = {
	TANK_SIZE_CLASS.SMALL: SMALL_ENGINE_PITCH_RANGES,
	TANK_SIZE_CLASS.MEDIUM: MEDIUM_ENGINE_PITCH_RANGES,
	TANK_SIZE_CLASS.LARGE: LARGE_ENGINE_PITCH_RANGES
}


static func get_speed_type_from_ratio(ratio: float) -> SPEED_TYPE:
	if ratio < 1.0 / 3.0:
		return SPEED_TYPE.SLOW
	if ratio < 2.0 / 3.0:
		return SPEED_TYPE.NORMAL
	return SPEED_TYPE.FAST


static func get_interpolation_factor(ratio: float, speed: SPEED_TYPE) -> float:
	match speed:
		SPEED_TYPE.SLOW:
			return ratio * 3.0
		SPEED_TYPE.NORMAL:
			return (ratio - 1.0 / 3.0) * 3.0
		SPEED_TYPE.FAST:
			return (ratio - 2.0 / 3.0) * 3.0
		_:
			return 0.0


static func calculate_pitch(ratio: float, pitch_ranges: Dictionary[SPEED_TYPE, Vector2]) -> float:
	var speed := get_speed_type_from_ratio(ratio)
	var pitch_range := pitch_ranges[speed]
	var t := get_interpolation_factor(ratio, speed)
	return lerp(pitch_range.x, pitch_range.y, clamp(t, 0.0, 1.0))
