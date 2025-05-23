extends RigidBody2D
class_name Tank
@export var tank_spec: TankSpec

var health: int
var is_player: bool
signal damage_taken(amount: int, tank: Tank)
signal tank_destroyed(tank: Tank)

#region references
@onready var turret : Turret = $Turret
@onready var cannon :Sprite2D= $Turret/Cannon
@onready var muzzle_marker :Marker2D= $Turret/Cannon/MuzzleMarker
@onready var hull : Hull = $Hull 
@onready var left_track :AnimatedSprite2D= $Hull/LeftTrack
@onready var right_track :AnimatedSprite2D= $Hull/RightTrack
@onready var collision_shape :CollisionShape2D= $CollisionShape2D
#endregion

#region input api
var right_track_input := 0.0
var left_track_input := 0.0
var turret_rotation_input := 0.0
#endregion

var current_shell_id: ShellManager.ShellId
var _has_initial_shell_been_set: bool = false
var distance_traveled: float = 0.0
@onready var _last_position: Vector2 = global_position

func _ready() -> void:
	self.linear_damp = tank_spec.linear_damping
	self.angular_damp = tank_spec.angular_damping
	tank_spec.initialize_tank_from_spec(self)

func set_active_shell(shell_id: ShellManager.ShellId) -> void:
	if not _has_initial_shell_been_set or shell_id != current_shell_id:
		current_shell_id = shell_id
		_has_initial_shell_been_set = true
		turret.reset_reload_timer()

func fire_shell(shell_id: ShellManager.ShellId) -> void:
	turret.fire_shell(shell_id)

func take_damage(amount: int) -> void:
	damage_taken.emit(amount, self)
	health -= amount
	if health <= 0:
		tank_destroyed.emit(self)

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	var forward := transform.x.normalized()

	# === Acceleration Based on Curve ===
	var current_speed := state.linear_velocity.length()
	var speed_ratio :float= clamp(current_speed / tank_spec.max_speed, 0.0, 1.0)
	var accel_scalar := tank_spec.acceleration_curve.sample(speed_ratio)

	if abs(left_track_input) > 0.01:
		var left_offset := transform.basis_xform(Vector2(0, -tank_spec.track_offset.y))
		var left_force := forward * left_track_input * accel_scalar * tank_spec.max_acceleration
		state.apply_force(left_force, left_offset)

	if abs(right_track_input) > 0.01:
		var right_offset := transform.basis_xform(Vector2(0, tank_spec.track_offset.y))
		var right_force := forward * right_track_input * accel_scalar * tank_spec.max_acceleration
		state.apply_force(right_force, right_offset)

	# === Delegate Sound & Track Animations ===
	hull.play_engine_sound(left_track_input, right_track_input)
	hull.animate_tracks(state.linear_velocity, state.angular_velocity)

	# === Distance tracking ===
	distance_traveled += global_position.distance_to(_last_position)
	_last_position = global_position
