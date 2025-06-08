class_name CannonSounds extends Resource

#region Caliber Class
const CaliberClass = Enums.GunCaliberClass


const CANNON_SOUND_MAP: Dictionary[CaliberClass, AudioStream] = {
	CaliberClass.SMALL: preload("res://entities/tank/shared_assets/sounds/cannon_fire/cannon_fire_small.ogg"),
	CaliberClass.MEDIUM: preload("res://entities/tank/shared_assets/sounds/cannon_fire/cannon_fire_medium.ogg"),
	CaliberClass.LARGE: preload("res://entities/tank/shared_assets/sounds/cannon_fire/cannon_fire_large.ogg")
}

static func get_cannon_sound(caliber_class: CaliberClass) -> AudioStream:
	return CANNON_SOUND_MAP[caliber_class]
#endregion