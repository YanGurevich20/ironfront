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