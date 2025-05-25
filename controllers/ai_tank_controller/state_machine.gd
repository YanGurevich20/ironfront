extends Node
class_name StateMachine

@export var detection_range := 600.0
@export var fight_range_max := 400.0
@export var fight_range_min := 100.0

enum State { PATROL, CHASE, FIGHT, DISENGAGE }

func determine_state(range_to_target: float, has_line_of_sight: bool) -> State:
	if range_to_target > detection_range:
		return State.PATROL
	elif range_to_target > fight_range_max or !has_line_of_sight:
		return State.CHASE
	elif range_to_target > fight_range_min:
		return State.FIGHT
	else:
		return State.DISENGAGE
