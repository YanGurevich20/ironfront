#? NOTE TO SELF
#* Shell collision shape is 0px wide, because the raycast goes from the middle of the shell.
#* The impact point determination algorithm requires tracing the shell's path to the tank,
#* from the shell's center.
#* In a case when the shell grazes the tank,
#* a wider collision polygon would detect the shell before its center enters the body.
#* Pros - easily implement tracing by one raycast
#* Cons - can miss the tank even when it looks like the sides of the shell should hit
class_name Shell extends Area2D

signal impact_resolved(
	shell: Shell,
	target_tank: Tank,
	result_type: ShellSpec.ImpactResultType,
	damage: int,
	hit_position: Vector2,
	post_impact_velocity: Vector2,
	post_impact_rotation: float,
	continue_simulation: bool
)

const TANK_SIDE_TYPE = Enums.TankSideType

var shell_spec: ShellSpec
var velocity: Vector2
var starting_global_position: Vector2
var firing_tank: Node2D
var damage: int
var shell_texture: Texture2D
var is_tracer: bool
var is_cosmetic_only: bool = false

@onready var sprite: Sprite2D = %Sprite2D
@onready var fire_particles: GPUParticles2D = %FireParticles
@onready var tracer_particles: GPUParticles2D = %TracerParticles
@onready var shell_tip: Marker2D = %ShellTip


func _ready() -> void:
	if shell_spec != null:
		sprite.texture = shell_spec.base_shell_type.projectile_texture
	Utils.connect_checked(body_entered, _on_body_entered)
	monitoring = not is_cosmetic_only
	monitorable = not is_cosmetic_only
	fire_particles.emitting = !is_tracer
	tracer_particles.emitting = is_tracer
	starting_global_position = global_position


func initialize(
	next_shell_spec: ShellSpec,
	muzzle: Marker2D,
	next_firing_tank: Node2D,
	cosmetic_only: bool = false
) -> void:
	shell_spec = next_shell_spec
	firing_tank = next_firing_tank
	is_cosmetic_only = cosmetic_only

	velocity = (muzzle.global_transform.x * shell_spec.muzzle_velocity)
	global_position = muzzle.global_position
	starting_global_position = muzzle.global_position
	rotation = velocity.angle()
	damage = shell_spec.damage
	shell_texture = shell_spec.base_shell_type.projectile_texture
	is_tracer = shell_spec.base_shell_type.is_tracer


func initialize_from_spawn(
	next_shell_spec: ShellSpec,
	spawn_position: Vector2,
	shell_velocity: Vector2,
	shell_rotation: float = 0.0,
	next_firing_tank: Node2D = null,
	cosmetic_only: bool = false
) -> void:
	shell_spec = next_shell_spec
	firing_tank = next_firing_tank
	is_cosmetic_only = cosmetic_only

	velocity = shell_velocity
	global_position = spawn_position
	starting_global_position = spawn_position
	rotation = shell_rotation
	damage = shell_spec.damage
	shell_texture = shell_spec.base_shell_type.projectile_texture
	is_tracer = shell_spec.base_shell_type.is_tracer


func _physics_process(delta: float) -> void:
	position += velocity * delta


func _on_body_entered(body: Node2D) -> void:
	if is_cosmetic_only:
		return
	if body == firing_tank:
		return
	if body.is_in_group("projectile_blocker"):
		queue_free()
		return
	if body is Tank:
		var tank: Tank = body
		var hit_params: ShellHelpers.ShellHitParams = ShellHelpers.handle_tank_hit(tank, self)
		if hit_params == null:
			return
		var armour_thickness: float = tank.tank_spec.hull_armor[hit_params.hit_side]
		var impact_result := shell_spec.get_impact_result(hit_params.normal_angle, armour_thickness)
		handle_impact_result(impact_result, tank, hit_params)


func handle_impact_result(
	impact_result: ShellSpec.ImpactResult, tank: Tank, hit_params: ShellHelpers.ShellHitParams
) -> void:
	var global_hit_point: Vector2 = tank.to_global(hit_params.hit_point)
	impact_result.damage = clamp(impact_result.damage, 0, tank._health)
	tank.handle_impact_result(impact_result)
	var should_continue_simulation: bool = (
		impact_result.result_type == ShellSpec.ImpactResultType.BOUNCED
	)
	if should_continue_simulation:
		starting_global_position = global_hit_point
		global_position = global_hit_point
		var surface_normal: Vector2 = get_surface_normal(hit_params.hit_side, tank)
		velocity = velocity.bounce(surface_normal)
		rotation = velocity.angle()
	impact_resolved.emit(
		self,
		tank,
		impact_result.result_type,
		impact_result.damage,
		global_hit_point,
		velocity,
		rotation,
		should_continue_simulation
	)
	if not should_continue_simulation:
		queue_free()


func get_surface_normal(hit_side: TANK_SIDE_TYPE, tank: Tank) -> Vector2:
	var local_normal: Vector2
	match hit_side:
		TANK_SIDE_TYPE.FRONT:
			local_normal = Vector2.RIGHT
		TANK_SIDE_TYPE.REAR:
			local_normal = Vector2.LEFT
		TANK_SIDE_TYPE.LEFT:
			local_normal = Vector2.UP
		TANK_SIDE_TYPE.RIGHT:
			local_normal = Vector2.DOWN
	return local_normal.rotated(tank.global_rotation)
