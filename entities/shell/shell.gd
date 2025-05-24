class_name Shell extends Area2D

var shell_id: ShellManager.ShellId
var firing_tank: Node2D
var damage: int
var velocity: Vector2
var shell_texture: Texture2D
var is_tracer: bool

@onready var shell_sprite: Sprite2D = $Sprite2D
@onready var fire_particles: GPUParticles2D = %FireParticles
@onready var tracer_particles: GPUParticles2D = %TracerParticles

func _ready() -> void:
	shell_sprite.texture = shell_texture
	body_entered.connect(_on_body_entered)
	fire_particles.emitting = !is_tracer
	tracer_particles.emitting = is_tracer

func initialize(_shell_id: ShellManager.ShellId, muzzle: Marker2D, _firing_tank: Node2D) -> void:
	var shell_spec: ShellSpec = ShellManager.SHELL_SPECS[_shell_id]
	shell_id = _shell_id
	damage = shell_spec.damage
	rotation = muzzle.global_rotation
	firing_tank = _firing_tank
	position = muzzle.global_position
	velocity = Vector2.RIGHT.rotated(rotation) * shell_spec.muzzle_velocity
	shell_texture = shell_spec.base_shell_type.projectile_texture
	is_tracer = shell_spec.base_shell_type.is_tracer

func _physics_process(delta: float)->void:
	position += velocity * delta

func _on_body_entered(body: Node2D) -> void:
	if body == firing_tank:
		return
	if body.is_in_group("projectile_blocker"):
		queue_free()
	if !body.is_in_group("damageable"):
		return
	if body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()
