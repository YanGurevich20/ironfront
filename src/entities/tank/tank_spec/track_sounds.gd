class_name TrackSounds extends Resource

const TANK_SIZE_CLASS = Enums.TankSizeClass

const SMALL_TRACK_SOUNDS: Dictionary[Enums.SpeedType, AudioStream] = {
	Enums.SpeedType.SLOW:
	preload("res://src/entities/tank/shared_assets/sounds/track_rattle/small/track_small_slow.ogg"),
	Enums.SpeedType.NORMAL:
	preload(
		"res://src/entities/tank/shared_assets/sounds/track_rattle/small/track_small_normal.ogg"
	),
	Enums.SpeedType.FAST:
	preload("res://src/entities/tank/shared_assets/sounds/track_rattle/small/track_small_fast.ogg")
}

const MEDIUM_TRACK_SOUNDS: Dictionary[Enums.SpeedType, AudioStream] = {
	Enums.SpeedType.SLOW:
	preload(
		"res://src/entities/tank/shared_assets/sounds/track_rattle/medium/track_medium_slow.ogg"
	),
	Enums.SpeedType.NORMAL:
	preload(
		"res://src/entities/tank/shared_assets/sounds/track_rattle/medium/track_medium_normal.ogg"
	),
	Enums.SpeedType.FAST:
	preload(
		"res://src/entities/tank/shared_assets/sounds/track_rattle/medium/track_medium_fast.ogg"
	)
}

const LARGE_TRACK_SOUNDS: Dictionary[Enums.SpeedType, AudioStream] = {
	Enums.SpeedType.SLOW:
	preload("res://src/entities/tank/shared_assets/sounds/track_rattle/large/track_large_slow.ogg"),
	Enums.SpeedType.NORMAL:
	preload(
		"res://src/entities/tank/shared_assets/sounds/track_rattle/large/track_large_normal.ogg"
	),
	Enums.SpeedType.FAST:
	preload("res://src/entities/tank/shared_assets/sounds/track_rattle/large/track_large_fast.ogg")
}

#TODO: Adjust pitch ranges based on track size and speed type
const SMALL_TRACK_PITCH_RANGES: Dictionary[Enums.SpeedType, Vector2] = {
	Enums.SpeedType.SLOW: Vector2(1.0, 1.2),
	Enums.SpeedType.NORMAL: Vector2(0.8, 1.1),
	Enums.SpeedType.FAST: Vector2(1, 1.2)
}
const MEDIUM_TRACK_PITCH_RANGES: Dictionary[Enums.SpeedType, Vector2] = {
	Enums.SpeedType.SLOW: Vector2(0.9, 1.1),
	Enums.SpeedType.NORMAL: Vector2(1.0, 1.2),
	Enums.SpeedType.FAST: Vector2(0.7, 1.1)
}
const LARGE_TRACK_PITCH_RANGES: Dictionary[Enums.SpeedType, Vector2] = {
	Enums.SpeedType.SLOW: Vector2(0.6, 1.0),
	Enums.SpeedType.NORMAL: Vector2(1.0, 1.3),
	Enums.SpeedType.FAST: Vector2(1.0, 1.3)
}

const TRACK_PITCH_RANGES: Dictionary[TANK_SIZE_CLASS, Dictionary] = {
	TANK_SIZE_CLASS.SMALL: SMALL_TRACK_PITCH_RANGES,
	TANK_SIZE_CLASS.MEDIUM: MEDIUM_TRACK_PITCH_RANGES,
	TANK_SIZE_CLASS.LARGE: LARGE_TRACK_PITCH_RANGES
}


static func get_track_sounds(
	tank_size: TANK_SIZE_CLASS
) -> Dictionary[Enums.SpeedType, AudioStream]:
	match tank_size:
		TANK_SIZE_CLASS.SMALL:
			return SMALL_TRACK_SOUNDS
		TANK_SIZE_CLASS.MEDIUM:
			return MEDIUM_TRACK_SOUNDS
		TANK_SIZE_CLASS.LARGE:
			return LARGE_TRACK_SOUNDS
		_:
			return SMALL_TRACK_SOUNDS
