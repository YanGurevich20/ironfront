class_name TankSpec extends Resource

const TankSideType = Enums.TankSideType
@export_category("Stats")
@export_group("Hull")
@export var health: int
@export var hull_armor: Dictionary[TankSideType, float] = {
	TankSideType.FRONT: 0.0,
	TankSideType.REAR: 0.0,
	TankSideType.LEFT: 0.0,
	TankSideType.RIGHT: 0.0
}
@export var linear_damping: float = 5.0 
@export var angular_damping: float = 15.0
@export var max_speed: float
@export var acceleration_curve: Curve
@export var max_acceleration: float
@export_group("Turret")
@export_range(0,300,0.1,"suffix:mm") var cannon_caliber: float
@export_range(0,120,0.1,"suffix:sec") var reload_time: float
@export_range(0,360,0.1,"suffix:deg/sec") var max_turret_traverse_speed: float
@export var shell_capacity: int
@export var allowed_shells: Array[ShellSpec]

@export_category("Info")
@export_group("Info")
@export var id: String
@export var display_name: String
@export var full_name: String
@export var nation: String
@export var dollar_cost: int

@export_category("Assets")
@export_group("Sprites")
@export var turret_sprite: AtlasTexture
@export var cannon_sprite: AtlasTexture
@export var hull_sprite: AtlasTexture
@export var track_sprite_frames: SpriteFrames
@export var preview_texture: Texture2D

@export_category("Dimensions")
@export_group("Hull")
@export var hull_size: Vector2
@export var track_width: int
@export_group("Turret")
@export var turret_size: Vector2
@export var turret_ring_diameter: int
@export var cannon_length: int

@export_category("Texture Data")
@export_group("Texture Data")
@export var track_frames: int
@export var track_offset: Vector2
@export var turret_pivot_offset: Vector2
@export var cannon_offset: Vector2
@export var muzzle_offset: Vector2

@export_category("Engine")
@export var engine_size_class: Enums.TankSizeClass = Enums.TankSizeClass.MEDIUM

func initialize_tank_from_spec(tank: Tank) -> void:
	#* Textures
	tank.turret.texture = turret_sprite
	tank.cannon.texture = cannon_sprite
	tank.hull.texture = hull_sprite
	tank.left_track.sprite_frames = track_sprite_frames
	tank.right_track.sprite_frames = track_sprite_frames

	#* Collision
	var collision_rectangle := RectangleShape2D.new()
	collision_rectangle.size = hull_size
	tank.collision_shape.shape = collision_rectangle

	#* Dimensions
	tank.turret.position = turret_pivot_offset
	tank.cannon.position = cannon_offset
	tank.muzzle_marker.position = muzzle_offset
	tank.left_track.position = - track_offset
	tank.right_track.position = track_offset

	#* Health
	tank._health = health

	#* Audio
	var stream_randomizer :AudioStreamRandomizer= tank.cannon_sound.stream
	var cannon_sound : AudioStream = CannonSounds.get_cannon_sound(get_caliber_class(cannon_caliber))
	stream_randomizer.add_stream(0, cannon_sound)

	#* Engine Sounds Setup (dynamic, like cannon sounds)
	tank.hull.setup_engine_sounds(engine_size_class)

const CaliberClass = Enums.GunCaliberClass
const CALIBER_THRESHOLD_MEDIUM: float = 76.0 #mm
const CALIBER_THRESHOLD_LARGE: float = 120.0 #mm

func get_caliber_class(caliber: float) -> CaliberClass:
	if caliber < CALIBER_THRESHOLD_MEDIUM: return CaliberClass.SMALL
	elif caliber < CALIBER_THRESHOLD_LARGE: return CaliberClass.MEDIUM
	else: return CaliberClass.LARGE
