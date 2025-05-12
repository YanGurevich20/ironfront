class_name TankV1 extends RigidBody2D

# === TankV1 Identity ===
@export var is_player: bool = false

# === Movement Settings ===
@export var acceleration: float = 100.0
@export var linear_friction: float = 1.0
@export var angular_friction: float = 2.0
@export var track_offset: float = 10.0

# === Health ===
@export var max_health: int = 5
var current_health: int = max_health

# === Engine Sound Settings ===
@export var base_engine_pitch: float = 1.0
@export var engine_pitch_lerp_speed: float = 2.0

# === Friction Settings ===
@export var side_damp_min: float = 0.1
@export var side_damp_max: float = 1.0
@export var side_damp_multiplier: float = 8.0

# === Input API ===
var right_track_input := 0.0
var left_track_input := 0.0
var turret_rotation_input := 0.0

func fire_shell() -> void:
	$Turret.fire_shell()

var distance_traveled: float = 0.0
@onready var _last_position: Vector2 = global_position


# === Sound management ===
@onready var engine_sound := get_node("EngineSound")
var engine_pitch_target := base_engine_pitch

@onready var turret := $Turret
signal shell_fired(shell: Shell, tank: TankV1)
func _ready() -> void:
	turret.shell_fired.connect(func(shell:Shell)->void:shell_fired.emit(shell, self))
	current_health = max_health
	linear_damp = linear_friction
	angular_damp = angular_friction
	#TODO: Consider adding a camera scene only when needed
	if is_player:
		add_to_group("player")
		var camera: Camera2D = get_node("Camera")
		camera.enabled = true

signal damage_taken(amount: int, tank: TankV1)
func take_damage(amount:int) -> void:
	damage_taken.emit(amount, self)
	current_health -= amount
	if current_health < 1:
		die()

signal tank_destroyed(tank: TankV1)
func die() -> void:
	tank_destroyed.emit(self)

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	engine_pitch_target = (abs(left_track_input) + abs(right_track_input)) * 0.5 + base_engine_pitch
	engine_sound.pitch_scale = lerp(engine_sound.pitch_scale, engine_pitch_target, engine_pitch_lerp_speed * state.step)

	# === Animation Handling ===
	$Hull.animate_tracks(state.linear_velocity, state.angular_velocity)

	# === Apply Track-Based Forces ===
	var forward :Vector2= transform.x.normalized()

	if abs(left_track_input) > 0.01:
		var left_offset :Vector2= transform.basis_xform(Vector2(0, -track_offset))
		var left_force :Vector2= forward * left_track_input * acceleration
		state.apply_force(left_force, left_offset)

	if abs(right_track_input) > 0.01:
		var right_offset: Vector2 = transform.basis_xform(Vector2(0, track_offset))
		var right_force: Vector2 = forward * right_track_input * acceleration
		state.apply_force(right_force, right_offset)

	# === Directional Friction (lateral sliding) ===
	var velocity_dir: Vector2 = state.linear_velocity.normalized()
	var alignment:float  = abs(forward.dot(velocity_dir))
	var side_damp_factor: float = lerp(side_damp_max, side_damp_min, alignment)
	state.linear_velocity = state.linear_velocity.lerp(Vector2.ZERO, side_damp_factor * state.step * side_damp_multiplier)

	# === General Friction (forward/backward) ===
	state.linear_velocity = state.linear_velocity.move_toward(Vector2.ZERO, linear_friction * state.step)

	# === Distance Tracking ===
	distance_traveled += global_position.distance_to(_last_position)
	_last_position = global_position
