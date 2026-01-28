class_name ShellHelpers

const TANK_SIDE_TYPE = Enums.TankSideType


static func handle_tank_hit(tank: Tank, shell: Shell) -> ShellHitParams:
	var shell_angle := shell.global_transform.get_rotation()
	var tank_angle := tank.global_transform.get_rotation()
	var relative_shell_rotation_deg := rad_to_deg(
		wrapf(shell_angle - tank_angle + PI, 0.0, 2 * PI) - PI
	)

	var shell_tip_local := tank.to_local(shell.shell_tip.global_position)
	var shell_origin_local := tank.to_local(shell.starting_global_position)

	var hit_result := find_tank_hit_info(
		shell_tip_local, shell_origin_local, tank.tank_spec.hull_size
	)
	if hit_result == null:
		push_warning("No intersection found - this shouldn't happen!")
		return null
	var normal_angle := calculate_normal_angle(relative_shell_rotation_deg, hit_result.side)
	return ShellHitParams.new(normal_angle, hit_result.side, hit_result.point)


static func find_tank_hit_info(
	shell_tip_local: Vector2, shell_origin_local: Vector2, tank_size: Vector2
) -> Intersection:
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


static func calculate_normal_angle(shell_rotation_deg: float, hit_side: TANK_SIDE_TYPE) -> float:
	var side_normal_angle_deg: float
	match hit_side:
		TANK_SIDE_TYPE.FRONT:  # +X face, inward normal points in -X direction (180°)
			side_normal_angle_deg = 180.0
		TANK_SIDE_TYPE.REAR:  # -X face, inward normal points in +X direction (0°)
			side_normal_angle_deg = 0.0
		TANK_SIDE_TYPE.LEFT:  # -Y face, inward normal points in +Y direction (90°)
			side_normal_angle_deg = 90.0
		TANK_SIDE_TYPE.RIGHT:  # +Y face, inward normal points in -Y direction (-90°)
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


static func find_all_box_intersections(
	start: Vector2, end: Vector2, box_size: Vector2
) -> Array[Intersection]:
	var half := box_size * 0.5
	var intersections: Array[Intersection] = []

	var sides: Dictionary[TANK_SIDE_TYPE, Array] = {
		TANK_SIDE_TYPE.REAR: [Vector2(-half.x, -half.y), Vector2(-half.x, half.y)],
		TANK_SIDE_TYPE.FRONT: [Vector2(half.x, -half.y), Vector2(half.x, half.y)],
		TANK_SIDE_TYPE.LEFT: [Vector2(-half.x, -half.y), Vector2(half.x, -half.y)],
		TANK_SIDE_TYPE.RIGHT: [Vector2(-half.x, half.y), Vector2(half.x, half.y)],
	}

	for side: TANK_SIDE_TYPE in sides.keys():
		var a: Vector2 = sides[side][0]
		var b: Vector2 = sides[side][1]
		var hit: Variant = Geometry2D.segment_intersects_segment(start, end, a, b)
		if hit != null:
			var checked_hit := hit as Vector2
			intersections.append(Intersection.new(side, checked_hit))

	return intersections


class Intersection:
	var side: TANK_SIDE_TYPE
	var point: Vector2

	func _init(_side: TANK_SIDE_TYPE, _point: Vector2) -> void:
		side = _side
		point = _point


class ShellHitParams:
	var normal_angle: float
	var hit_side: TANK_SIDE_TYPE
	var hit_point: Vector2

	func _init(_normal_angle: float, _hit_side: TANK_SIDE_TYPE, _hit_point: Vector2) -> void:
		normal_angle = _normal_angle
		hit_side = _hit_side
		hit_point = _hit_point
