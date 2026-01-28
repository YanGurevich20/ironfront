class_name CannonSounds extends Resource

const CALIBER_CLASS = Enums.GunCaliberClass

const CANNON_SOUND_MAP: Dictionary[CALIBER_CLASS, AudioStream] = {
	CALIBER_CLASS.SMALL:
	preload("res://entities/tank/shared_assets/sounds/cannon_fire/cannon_fire_small.ogg"),
	CALIBER_CLASS.MEDIUM:
	preload("res://entities/tank/shared_assets/sounds/cannon_fire/cannon_fire_medium.ogg"),
	CALIBER_CLASS.LARGE:
	preload("res://entities/tank/shared_assets/sounds/cannon_fire/cannon_fire_large.ogg")
}


static func get_cannon_sound(caliber: CALIBER_CLASS) -> AudioStream:
	return CANNON_SOUND_MAP[caliber]
