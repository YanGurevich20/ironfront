#? NOTE TO SELF
#* Shell collision shape is 0px wide, because the raycast goes from the middle of the shell.
#* The impact point determination algorithm requires tracing the shell's path to the tank, from the shell's center.
#* In a case when the shell grazes the tank, a wider collision polygon would detect the shell before its center enters the body.
class_name Shell extends Area2D

const TankSideType = Enums.TankSideType
var shell_id: ShellManager.ShellId
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
	var shell_spec: ShellSpec = ShellManager.SHELL_SPECS[_shell_id]
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
	if !body.is_in_group("damageable"):
		return
	if body is Tank:
		var tank: Tank = body
		tank.take_damage(damage)
		velocity = Vector2.ZERO
		handle_tank_hit(tank)

func handle_tank_hit(tank: Tank) -> void:
	var shell_angle := global_transform.get_rotation()
	var tank_angle := tank.global_transform.get_rotation()
	var relative_shell_rotation_deg := rad_to_deg(wrapf(shell_angle - tank_angle + PI, 0.0, 2*PI) - PI)

	var shell_tip_local := tank.to_local(shell_tip.global_position)
	var shell_origin_local := tank.to_local(starting_global_position)

	var hit_result := find_tank_hit_info(shell_tip_local, shell_origin_local, tank.tank_spec.hull_size)
	if hit_result:
		var normal_angle := calculate_normal_angle(relative_shell_rotation_deg, hit_result.side)

		print("Shell hit side: ", TankSideType.find_key(hit_result.side))
		print("Shell entry point: ", hit_result.point)
		print("Normal angle: ", normal_angle, "°")
	else:
		push_warning("No intersection found - this shouldn't happen!")

func find_tank_hit_info(shell_tip_local: Vector2, shell_origin_local: Vector2, tank_size: Vector2) -> Intersection:
	var intersections := find_all_box_intersections(shell_tip_local, shell_origin_local, tank_size)

	if intersections.is_empty():
		return null

	# Find the intersection furthest from the shell tip (closest to origin)
	var furthest_intersection := intersections[0]
	var max_distance := shell_tip_local.distance_to(furthest_intersection.point)

	for intersection in intersections:
		var distance := shell_tip_local.distance_to(intersection.point)
		if distance > max_distance:
			max_distance = distance
			furthest_intersection = intersection

	return furthest_intersection

func calculate_normal_angle(shell_rotation_deg: float, hit_side: TankSideType) -> float:
	var side_normal_angle_deg: float
	match hit_side:
		TankSideType.FRONT:  # +X face, inward normal points in -X direction (180°)
			side_normal_angle_deg = 180.0
		TankSideType.REAR:   # -X face, inward normal points in +X direction (0°)
			side_normal_angle_deg = 0.0
		TankSideType.LEFT:   # -Y face, inward normal points in +Y direction (90°)
			side_normal_angle_deg = 90.0
		TankSideType.RIGHT:  # +Y face, inward normal points in -Y direction (-90°)
			side_normal_angle_deg = -90.0

	# Calculate angle between shell direction and inward surface normal
	var angle_diff := shell_rotation_deg - side_normal_angle_deg
	# Normalize to [-180, 180] range
	angle_diff = wrapf(angle_diff + 180.0, 0.0, 360.0) - 180.0
	# Get the acute angle (0° to 90°)
	var normal_angle: float = abs(angle_diff)
	if normal_angle > 90.0:
		normal_angle = 180.0 - normal_angle

	return normal_angle

func find_all_box_intersections(start: Vector2, end: Vector2, box_size: Vector2) -> Array[Intersection]:
	var half := box_size * 0.5
	var intersections: Array[Intersection] = []

	var sides: Dictionary[TankSideType, Array] = {
		TankSideType.REAR: [Vector2(-half.x, -half.y), Vector2(-half.x, half.y)],
		TankSideType.FRONT: [Vector2(half.x, -half.y), Vector2(half.x, half.y)],
		TankSideType.LEFT: [Vector2(-half.x, -half.y), Vector2(half.x, -half.y)],
		TankSideType.RIGHT: [Vector2(-half.x, half.y), Vector2(half.x, half.y)],
	}

	for side: TankSideType in sides.keys():
		var a: Vector2 = sides[side][0]
		var b: Vector2 = sides[side][1]
		var hit: Variant = Geometry2D.segment_intersects_segment(start, end, a, b)
		if hit != null:
			var checked_hit := hit as Vector2
			intersections.append(Intersection.new(side, checked_hit))

	return intersections

class Intersection:
	var side: TankSideType
	var point: Vector2

	func _init(_side: TankSideType, _point: Vector2) -> void:
		side = _side
		point = _point
