#? NOTE TO SELF
#* Shell collision shape is 0px wide, because the raycast goes from the middle of the shell.
#* The impact point determination algorithm requires tracing the shell's path to the tank,
#* from the shell's center.
#* In a case when the shell grazes the tank,
#* a wider collision polygon would detect the shell before its center enters the body.
#* Pros - easily implement tracing by one raycast
#* Cons - can miss the tank even when it looks like the sides of the shell should hit
class_name Shell extends Area2D

const TANK_SIDE_TYPE = Enums.TankSideType

var shell_spec: ShellSpec
var velocity: Vector2
var starting_global_position: Vector2
var firing_tank: Node2D
var damage: int
var shell_texture: Texture2D
var is_tracer: bool

@onready var sprite: Sprite2D = %Sprite2D
@onready var fire_particles: GPUParticles2D = %FireParticles
@onready var tracer_particles: GPUParticles2D = %TracerParticles
@onready var shell_tip: Marker2D = %ShellTip


func _ready() -> void:
	if shell_spec != null:
		sprite.texture = shell_spec.base_shell_type.projectile_texture
	Utils.connect_checked(body_entered, _on_body_entered)
	fire_particles.emitting = !is_tracer
	tracer_particles.emitting = is_tracer
	starting_global_position = global_position


func initialize(_shell_spec: ShellSpec, muzzle: Marker2D, _firing_tank: Node2D) -> void:
	shell_spec = _shell_spec
	firing_tank = _firing_tank

	velocity = (muzzle.global_transform.x * shell_spec.muzzle_velocity)
	global_position = muzzle.global_position
	starting_global_position = muzzle.global_position
	rotation = velocity.angle()
	damage = shell_spec.damage
	shell_texture = shell_spec.base_shell_type.projectile_texture
	is_tracer = shell_spec.base_shell_type.is_tracer


func _physics_process(delta: float) -> void:
	position += velocity * delta


func _on_body_entered(body: Node2D) -> void:
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
	if impact_result.result_type == ShellSpec.ImpactResultType.BOUNCED:
		starting_global_position = global_hit_point
		global_position = global_hit_point
		var surface_normal: Vector2 = get_surface_normal(hit_params.hit_side, tank)
		velocity = velocity.bounce(surface_normal)
		rotation = velocity.angle()
	else:
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
