extends RigidBody2D
class_name Tank
@export var tank_spec: TankSpec

var health: int
var is_player: bool
signal damage_taken(amount: int, tank: Tank)
signal tank_destroyed(tank: Tank)
signal shell_fired(shell: Shell, tank: Tank)

#region references
@onready var turret := $Turret
@onready var cannon := $Turret/Cannon
@onready var muzzle_marker := $Turret/Cannon/MuzzleMarker
@onready var hull := $Hull
@onready var left_track := $Hull/LeftTrack
@onready var right_track := $Hull/RightTrack
@onready var collision_shape := $CollisionShape2D
#endregion

#region input api
var right_track_input := 0.0
var left_track_input := 0.0
var turret_rotation_input := 0.0
#endregion

var distance_traveled: float = 0.0
@onready var _last_position: Vector2 = global_position

func _ready() -> void:
	self.linear_damp = tank_spec.linear_damping
	self.angular_damp = tank_spec.angular_damping
	tank_spec.initialize_tank_from_spec(self)
	turret.shell_fired.connect(func(shell: Shell) -> void: shell_fired.emit(shell, self))

func fire_shell() -> void:
	turret.fire_shell()

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
