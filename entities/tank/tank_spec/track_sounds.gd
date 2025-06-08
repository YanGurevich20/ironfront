class_name TrackSounds extends Resource

const TankSizeClass = Enums.TankSizeClass

const SMALL_TRACK_SOUNDS: Dictionary[Enums.SpeedType, AudioStream] = {
	Enums.SpeedType.SLOW: preload("res://entities/tank/shared_assets/sounds/track_rattle/small/track_small_slow.ogg"),
	Enums.SpeedType.NORMAL: preload("res://entities/tank/shared_assets/sounds/track_rattle/small/track_small_normal.ogg"),
	Enums.SpeedType.FAST: preload("res://entities/tank/shared_assets/sounds/track_rattle/small/track_small_fast.ogg")
}

const MEDIUM_TRACK_SOUNDS: Dictionary[Enums.SpeedType, AudioStream] = {
	Enums.SpeedType.SLOW: preload("res://entities/tank/shared_assets/sounds/track_rattle/medium/track_medium_slow.ogg"),
	Enums.SpeedType.NORMAL: preload("res://entities/tank/shared_assets/sounds/track_rattle/medium/track_medium_normal.ogg"),
	Enums.SpeedType.FAST: preload("res://entities/tank/shared_assets/sounds/track_rattle/medium/track_medium_fast.ogg")
}

const LARGE_TRACK_SOUNDS: Dictionary[Enums.SpeedType, AudioStream] = {
	Enums.SpeedType.SLOW: preload("res://entities/tank/shared_assets/sounds/track_rattle/large/track_large_slow.ogg"),
	Enums.SpeedType.NORMAL: preload("res://entities/tank/shared_assets/sounds/track_rattle/large/track_large_normal.ogg"),
	Enums.SpeedType.FAST: preload("res://entities/tank/shared_assets/sounds/track_rattle/large/track_large_fast.ogg")
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

const TRACK_PITCH_RANGES: Dictionary[Enums.TankSizeClass, Dictionary] = {
	Enums.TankSizeClass.SMALL: SMALL_TRACK_PITCH_RANGES,
	Enums.TankSizeClass.MEDIUM: MEDIUM_TRACK_PITCH_RANGES,
	Enums.TankSizeClass.LARGE: LARGE_TRACK_PITCH_RANGES
}

static func get_track_sounds(tank_size_class: TankSizeClass) -> Dictionary[Enums.SpeedType, AudioStream]:
	match tank_size_class:
		TankSizeClass.SMALL:
			return SMALL_TRACK_SOUNDS
		TankSizeClass.MEDIUM:
			return MEDIUM_TRACK_SOUNDS
		TankSizeClass.LARGE:
			return LARGE_TRACK_SOUNDS
		_:
			return SMALL_TRACK_SOUNDS