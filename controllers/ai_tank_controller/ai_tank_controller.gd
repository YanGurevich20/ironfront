extends Node

@export var full_speed_traverse_zone: float = 0.9
@export var compount_turn_zone: float = 0.2
@export var aim_tolerance_deg: float = 10.0
@export var hold_to_fire_time: float = 6.0

var time_on_target: float = 0.0

@onready var tank: Tank = get_parent()
@onready var nav_agent: NavigationAgent2D = tank.get_node("NavigationAgent2D")
@onready var state_machine: StateMachine = $StateMachine


func _physics_process(delta: float) -> void:
	var tanks_group_nodes := get_tree().get_nodes_in_group("tank")
	var tanks: Array[Tank] = []
	tanks.assign(tanks_group_nodes.filter(func(node: Node) -> bool: return node is Tank))

	var player_tanks: Array[Tank] = tanks.filter(func(t: Tank) -> bool: return t.is_player)

	if player_tanks.is_empty():
		push_warning("No player tanks found")
		return
	if player_tanks.size() > 1:
		push_warning("Multiple player tanks found")
		return
	var target: Tank = player_tanks[0]

	var distance_to_target: float = tank.global_position.distance_to(target.global_position)
	var has_line_of_sight: bool = tank.turret.has_line_of_sight(target)
	var current_state: StateMachine.State = state_machine.determine_state(
		distance_to_target, has_line_of_sight
	)

	match current_state:
		StateMachine.State.PATROL:
			patrol_behaviour()
		StateMachine.State.CHASE:
			chase_behaviour(target.global_position)
		StateMachine.State.FIGHT:
			fight_behaviour(target, delta)
		StateMachine.State.DISENGAGE:
			disengage_behaviour(target, delta)


# -------------------------
# State Behaviours
# -------------------------
func patrol_behaviour() -> void:
	reset_navigation()
	reset_aim()


func chase_behaviour(target_position: Vector2) -> void:
	drive_to_position(target_position)
	reset_aim()


func fight_behaviour(target: Node2D, delta: float) -> void:
	reset_navigation()  # TODO
	aim_and_fire_at(target, delta)


func disengage_behaviour(target: Node2D, delta: float) -> void:
	var to_target: Vector2 = (target.global_position - tank.global_position).normalized()
	var escape_position: Vector2 = tank.global_position - to_target * 100
	drive_to_position(escape_position)
	aim_and_fire_at(target, delta)


# -------------------------
# Navigation
# -------------------------
func drive_to_position(target_position: Vector2, reverse_threshold: float = 200.0) -> void:
	nav_agent.target_position = target_position

	if nav_agent.is_navigation_finished():
		tank.left_track_input = 0.0
		tank.right_track_input = 0.0
		return

	var next_point: Vector2 = nav_agent.get_next_path_position()
	var to_target: Vector2 = next_point - tank.global_position
	var distance_to_target: float = to_target.length()
	var to_target_dir: Vector2 = to_target.normalized()
	var tank_facing: Vector2 = tank.transform.x.normalized()
	var tank_rear: Vector2 = -tank_facing  # Tank's rear direction

	# Determine if we should drive forward or reverse
	var drive_forward: bool = true
	if distance_to_target < reverse_threshold:
		# Check if tank's rear is already facing roughly toward the target (within ±30%)
		var rear_angle_to_target: float = abs(tank_rear.angle_to(to_target_dir))
		var angle_threshold: float = PI * 0.3  # 30% of PI is about 54 degrees

		if rear_angle_to_target < angle_threshold:
			drive_forward = false  # Drive in reverse

	# Direction vector to use for angle calculation
	var reference_dir: Vector2 = tank_facing if drive_forward else tank_rear
	var target_dir: Vector2 = to_target_dir

	var angle_diff: float = wrapf(reference_dir.angle_to(target_dir), -PI, PI)
	var normalized_angle: float = angle_diff / PI
	var turn_input: float = get_scaled_turn_input(normalized_angle)
	if abs(normalized_angle) <= compount_turn_zone:
		# Move while turning
		var drive_speed: float = 1.0 if drive_forward else -1.0
		tank.left_track_input = drive_speed + turn_input
		tank.right_track_input = drive_speed - turn_input
	else:
		# Neutral steer: spin in place
		tank.left_track_input = turn_input
		tank.right_track_input = -turn_input


# -------------------------
# Aiming & Firing
# -------------------------
func aim_and_fire_at(target: Node2D, delta: float) -> void:
	var target_position: Vector2 = target.global_position
	var angle_to_target: float = get_angle_diff(
		tank.turret.global_position, tank.turret.global_rotation, target_position
	)
	var angle_deg: float = abs(rad_to_deg(angle_to_target))

	# Rotate turret
	var normalized_angle: float = angle_to_target / PI
	tank.turret_rotation_input = get_scaled_turn_input(normalized_angle)

	# Fire if aligned
	if angle_deg < aim_tolerance_deg and tank.turret.has_line_of_sight(target):
		time_on_target += delta
		if time_on_target >= hold_to_fire_time:
			tank.fire_shell()
			time_on_target = 0.0
	else:
		time_on_target = 0.0


# -------------------------
# Helpers
# -------------------------
func reset_navigation() -> void:
	drive_to_position(tank.global_position)


func reset_aim() -> void:
	tank.turret_rotation_input = 0.0


func get_scaled_turn_input(normalized_angle: float) -> float:
	var multiplier: float = 1.0 / (1.0 - full_speed_traverse_zone)
	return clamp(normalized_angle * multiplier, -1.0, 1.0)


func get_angle_diff(from_position: Vector2, from_rotation: float, to_position: Vector2) -> float:
	var to_vector: Vector2 = (to_position - from_position).normalized()
	return wrapf(to_vector.angle() - from_rotation, -PI, PI)
