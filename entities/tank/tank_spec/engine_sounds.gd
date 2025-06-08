class_name EngineSounds extends Resource

const TankSizeClass = Enums.TankSizeClass
const SpeedType = Enums.SpeedType

const SMALL_ENGINE_SOUNDS: Dictionary[SpeedType, AudioStream] = {
	SpeedType.SLOW: preload("res://entities/tank/shared_assets/sounds/engine/small/engine_small_slow.ogg"),
	SpeedType.NORMAL: preload("res://entities/tank/shared_assets/sounds/engine/small/engine_small_normal.ogg"),
	SpeedType.FAST: preload("res://entities/tank/shared_assets/sounds/engine/small/engine_small_fast.ogg")
}
const MEDIUM_ENGINE_SOUNDS: Dictionary[SpeedType, AudioStream] = {
	SpeedType.SLOW: preload("res://entities/tank/shared_assets/sounds/engine/medium/engine_medium_slow.ogg"),
	SpeedType.NORMAL: preload("res://entities/tank/shared_assets/sounds/engine/medium/engine_medium_normal.ogg"),
	SpeedType.FAST: preload("res://entities/tank/shared_assets/sounds/engine/medium/engine_medium_fast.ogg")
}
const LARGE_ENGINE_SOUNDS: Dictionary[SpeedType, AudioStream] = {
	SpeedType.SLOW: preload("res://entities/tank/shared_assets/sounds/engine/large/engine_large_slow.ogg"),
	SpeedType.NORMAL: preload("res://entities/tank/shared_assets/sounds/engine/large/engine_large_normal.ogg"),
	SpeedType.FAST: preload("res://entities/tank/shared_assets/sounds/engine/large/engine_large_fast.ogg")
}

const ENGINE_SOUNDS: Dictionary[TankSizeClass, Dictionary] = {
	TankSizeClass.SMALL: SMALL_ENGINE_SOUNDS,
	TankSizeClass.MEDIUM: MEDIUM_ENGINE_SOUNDS,
	TankSizeClass.LARGE: LARGE_ENGINE_SOUNDS
}

#TODO: Adjust pitch ranges based on engine size and speed type
const SMALL_ENGINE_PITCH_RANGES: Dictionary[SpeedType, Vector2] = {
	SpeedType.SLOW: Vector2(0.8, 1.2),
	SpeedType.NORMAL: Vector2(0.7, 1.5),
	SpeedType.FAST: Vector2(0.9, 1.3)
}
const MEDIUM_ENGINE_PITCH_RANGES: Dictionary[SpeedType, Vector2] = {
	SpeedType.SLOW: Vector2(0.8, 1.2),
	SpeedType.NORMAL: Vector2(0.7, 1.5),
	SpeedType.FAST: Vector2(0.9, 1.3)
}
const LARGE_ENGINE_PITCH_RANGES: Dictionary[SpeedType, Vector2] = {
	SpeedType.SLOW: Vector2(0.8, 1.2),
	SpeedType.NORMAL: Vector2(0.7, 1.5),
	SpeedType.FAST: Vector2(0.9, 1.3)
}

const ENGINE_PITCH_RANGES: Dictionary[TankSizeClass, Dictionary] = {
	TankSizeClass.SMALL: SMALL_ENGINE_PITCH_RANGES,
	TankSizeClass.MEDIUM: MEDIUM_ENGINE_PITCH_RANGES,
	TankSizeClass.LARGE: LARGE_ENGINE_PITCH_RANGES
}

static func get_speed_type_from_ratio(ratio: float) -> SpeedType:
	if ratio < 1.0/3.0:
		return SpeedType.SLOW
	elif ratio < 2.0/3.0:
		return SpeedType.NORMAL
	else:
		return SpeedType.FAST

static func get_interpolation_factor(ratio: float, speed_type: SpeedType) -> float:
	match speed_type:
		SpeedType.SLOW:
			return ratio * 3.0
		SpeedType.NORMAL:
			return (ratio - 1.0/3.0) * 3.0
		SpeedType.FAST:
			return (ratio - 2.0/3.0) * 3.0
		_:
			return 0.0

static func calculate_pitch(ratio: float, pitch_ranges: Dictionary[SpeedType, Vector2]) -> float:
	var speed_type := get_speed_type_from_ratio(ratio)
	var pitch_range := pitch_ranges[speed_type]
	var t := get_interpolation_factor(ratio, speed_type)
	return lerp(pitch_range.x, pitch_range.y, clamp(t, 0.0, 1.0))