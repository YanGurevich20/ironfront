class_name StateMachine
extends Node

enum State { PATROL = 0, CHASE = 1, FIGHT = 2, DISENGAGE = 3 }

@export var detection_range := 600.0
@export var fight_range_max := 400.0
@export var fight_range_min := 100.0


func determine_state(range_to_target: float, has_line_of_sight: bool) -> State:
	if range_to_target > detection_range:
		return State.PATROL
	if range_to_target > fight_range_max or !has_line_of_sight:
		return State.CHASE
	if range_to_target > fight_range_min:
		return State.FIGHT
	return State.DISENGAGE
