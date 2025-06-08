#? NOTE TO SELF
#* Shell collision shape is 0px wide, because the raycast goes from the middle of the shell.
#* The impact point determination algorithm requires tracing the shell's path to the tank, from the shell's center.
#* In a case when the shell grazes the tank, a wider collision polygon would detect the shell before its center enters the body.
#* Pros - easily implement tracing by one raycast
#* Cons - can miss the tank even when it looks like the sides of the shell should hit
class_name Shell extends Area2D

const TankSideType = Enums.TankSideType
var shell_id: ShellManager.ShellId
var shell_spec: ShellSpec
var firing_tank: Node2D
var damage: int
var velocity: Vector2
var shell_texture: Texture2D
var is_tracer: bool
var starting_global_position: Vector2

@onready var shell_sprite: Sprite2D = $Sprite2D
@onready var fire_particles: GPUParticles2D = %FireParticles
@onready var tracer_particles: GPUParticles2D = %TracerParticles
@onready var shell_tip: Marker2D = %ShellTip

func _ready() -> void:
	shell_sprite.texture = shell_texture
	body_entered.connect(_on_body_entered)
	fire_particles.emitting = !is_tracer
	tracer_particles.emitting = is_tracer
	starting_global_position = global_position

func initialize(_shell_id: ShellManager.ShellId, muzzle: Marker2D, _firing_tank: Node2D) -> void:
	shell_spec = ShellManager.SHELL_SPECS[_shell_id]
	shell_id = _shell_id
	damage = shell_spec.damage
	rotation = muzzle.global_rotation
	firing_tank = _firing_tank
	position = muzzle.global_position
	velocity = Vector2.RIGHT.rotated(rotation) * shell_spec.muzzle_velocity
	shell_texture = shell_spec.base_shell_type.projectile_texture
	is_tracer = shell_spec.base_shell_type.is_tracer

func _physics_process(delta: float) -> void:
	position += velocity * delta

func _on_body_entered(body: Node2D) -> void:
	if body == firing_tank:
		return
	if body.is_in_group("projectile_blocker"):
		queue_free()
	if body is Tank:
		var tank: Tank = body
		var hit_params: ShellHelpers.ShellHitParams = ShellHelpers.handle_tank_hit(tank, self)
		if hit_params == null: return
		var armour_thickness: float = tank.tank_spec.hull_armor[hit_params.hit_side]
		var impact_result := shell_spec.get_impact_result(hit_params.normal_angle, armour_thickness)
		handle_impact_result(impact_result, tank, hit_params)

func handle_impact_result(impact_result: ShellSpec.ImpactResult, tank: Tank, hit_params: ShellHelpers.ShellHitParams) -> void:
	var global_hit_point: Vector2 = tank.to_global(hit_params.hit_point)
	tank.handle_impact_result(impact_result)
	if impact_result.result_type == ShellSpec.ImpactResultType.BOUNCED:
		starting_global_position = global_hit_point
		global_position = global_hit_point
		var surface_normal: Vector2 = get_surface_normal(hit_params.hit_side, tank)
		velocity = velocity.bounce(surface_normal)
		rotation = velocity.angle()
	else:
		queue_free()

func get_surface_normal(hit_side: TankSideType, tank: Tank) -> Vector2:
	var local_normal: Vector2
	match hit_side:
		TankSideType.FRONT: local_normal = Vector2.RIGHT
		TankSideType.REAR: local_normal = Vector2.LEFT
		TankSideType.LEFT: local_normal = Vector2.UP
		TankSideType.RIGHT: local_normal = Vector2.DOWN
	return local_normal.rotated(tank.global_rotation)
