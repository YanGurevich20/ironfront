class_name Tank
extends RigidBody2D

@warning_ignore("unused_signal")
signal damage_taken(amount: int, tank: Tank)
@warning_ignore("unused_signal")
signal tank_destroyed(tank: Tank)

@export var tank_spec: TankSpec

var is_player: bool
var controller: Node
var right_track_input := 0.0
var left_track_input := 0.0
var turret_rotation_input := 0.0
var distance_traveled: float = 0.0
var settings_data: SettingsData
var _health: int

@onready var turret: Turret = %Turret
@onready var cannon: Sprite2D = %Cannon
@onready var muzzle_marker: Marker2D = %MuzzleMarker
@onready var hull: Hull = %Hull
@onready var left_track: AnimatedSprite2D = %LeftTrack
@onready var right_track: AnimatedSprite2D = %RightTrack
@onready var collision_shape: CollisionShape2D = %CollisionShape2D
@onready var audio_listener: AudioListener2D = %AudioListener2D
@onready var camera_2d: Camera2D = %Camera2D
@onready var death_explosion_sprite: AnimatedSprite2D = %DeathExploisonSprite
@onready var death_explosion_sound: AudioStreamPlayer2D = %DeathExplosionSound
@onready var cannon_sound: AudioStreamPlayer2D = %CannonSound
@onready var tank_destruction_shader: ShaderMaterial = preload(
	"res://entities/tank/shaders/tank_destruction_shader_material.tres"
)
@onready var tank_hud: TankHUD = %TankHUD
@onready var _last_position: Vector2 = global_position


func _ready() -> void:
	settings_data = SettingsData.get_instance()
	self.linear_damp = tank_spec.linear_damping
	self.angular_damp = tank_spec.angular_damping
	tank_spec.initialize_tank_from_spec(self)
	hull.setup_sounds(tank_spec.engine_size_class)
	tank_hud.initialize(self)
	if controller:
		add_child(controller)
	if is_player:
		audio_listener.make_current()
		camera_2d.make_current()
		Utils.connect_checked(SignalBus.settings_changed, _apply_settings)
		_apply_settings()


func _apply_settings() -> void:
	var zoom_level: float = settings_data.zoom_level
	camera_2d.zoom = Vector2(zoom_level, zoom_level)


func set_current_shell_spec(shell_spec: ShellSpec) -> void:
	turret.set_current_shell_spec(shell_spec)


func set_remaining_shell_count(count: int) -> void:
	turret.remaining_shell_count = count


func fire_shell() -> void:
	turret.fire_shell()


func handle_impact_result(result: ShellSpec.ImpactResult) -> void:
	tank_hud.handle_impact_result(result)
	take_damage(result.damage)


func setup_controller(controller_node: Node) -> void:
	controller = controller_node


func take_damage(amount: int) -> void:
	damage_taken.emit(amount, self)
	_health = clamp(_health - amount, 0, tank_spec.health)
	tank_hud.update_health_bar(_health)
	if _health <= 0:
		handle_tank_destroyed()


func handle_tank_destroyed() -> void:
	if controller:
		controller.queue_free()
	reset_input()
	hull.stop_sounds()
	tank_destroyed.emit(self)
	remove_from_group("tank")
	add_to_group("projectile_blocker")
	apply_destruction_effects()


func apply_destruction_effects() -> void:
	var destruction_material: ShaderMaterial = tank_destruction_shader.duplicate()
	hull.material = destruction_material
	turret.material = destruction_material
	cannon.material = destruction_material

	# Randomize turret rotation and position
	var rand_rot: float = randf_range(-10, 10)
	turret.rotation_degrees += rand_rot
	var rand_offset: Vector2 = Vector2(randf_range(-3, 3), randf_range(-3, 3))
	turret.position += rand_offset

	death_explosion_sprite.play()
	death_explosion_sound.play()


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	var forward := transform.x.normalized()
	var sideways := transform.y.normalized()

	# === Acceleration Based on Curve ===
	var current_speed := get_forward_speed(state.linear_velocity)
	var speed_ratio: float = clamp((current_speed) / tank_spec.max_speed, 0.0, 1.0)
	var accel_scalar := tank_spec.acceleration_curve.sample(speed_ratio)

	# === Apply Forces Per Track ===
	if abs(left_track_input) > 0.01:
		var left_offset := transform.basis_xform(Vector2(0, -tank_spec.track_offset.y))
		var left_force := forward * left_track_input * accel_scalar * tank_spec.max_acceleration
		state.apply_force(left_force, left_offset)

	if abs(right_track_input) > 0.01:
		var right_offset := transform.basis_xform(Vector2(0, tank_spec.track_offset.y))
		var right_force := forward * right_track_input * accel_scalar * tank_spec.max_acceleration
		state.apply_force(right_force, right_offset)

	# === Reduce Sideways Sliding ===
	var lateral_velocity := state.linear_velocity.dot(sideways)
	var lateral_damping_force := -sideways * lateral_velocity * tank_spec.linear_damping
	state.apply_force(lateral_damping_force)

	# === Delegate all hull logic to master process ===
	hull.process(left_track_input, right_track_input, state.linear_velocity, state.angular_velocity)

	# === Delegate turret rotation ===
	turret.process(state.step, turret_rotation_input)

	# === Distance Tracking ===
	distance_traveled += global_position.distance_to(_last_position)
	_last_position = global_position

	# === HUD Positioning ===
	tank_hud.update_hud_position()


func get_forward_speed(velocity: Vector2) -> float:
	var forward := transform.x.normalized()
	return velocity.dot(forward)


func reset_input() -> void:
	right_track_input = 0.0
	left_track_input = 0.0
	turret_rotation_input = 0.0
