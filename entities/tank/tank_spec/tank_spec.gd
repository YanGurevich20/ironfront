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
@export var linear_damping: float = 5.0 # Added for Godot's RigidBody2D linear damp
@export var angular_damping: float = 15.0 # Added for Godot's RigidBody2D angular damp
@export var max_speed: float
@export var acceleration_curve: Curve
@export var max_acceleration: float
@export_group("Turret")
@export var cannon_caliber: float #mm
@export var reload_time: float #sec
@export var max_turret_traverse_speed: float #deg/sec
@export var shell_capacity: int
@export var allowed_shells: Array[ShellManager.ShellId]

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

func initialize_tank_from_spec(tank: Tank) -> void:
	tank.turret.texture = turret_sprite
	tank.cannon.texture = cannon_sprite
	tank.hull.texture = hull_sprite
	tank.left_track.sprite_frames = track_sprite_frames
	tank.right_track.sprite_frames = track_sprite_frames

	var collision_rectangle := RectangleShape2D.new()
	collision_rectangle.size = hull_size
	tank.collision_shape.shape = collision_rectangle

	tank.turret.position = turret_pivot_offset
	tank.cannon.position = cannon_offset
	tank.muzzle_marker.position = muzzle_offset
	tank.left_track.position = - track_offset
	tank.right_track.position = track_offset

	tank._health = health
