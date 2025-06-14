# objective_manager.gd
class_name ObjectiveManager extends Resource
@export var objectives: Array[Objective]

enum ObjectiveResult {SCORE=0, COUNT=1}

func evaluate_objectives(level_metrics: Dictionary[Metrics.Metric, int]) -> void:
	if objectives.size() == 0:
		push_warning("Empty objective array on current level")
		return
	for objective in objectives:
		if objective == null:
			push_warning("null objective in array")
			return
		var level_value: int = level_metrics[objective.metric]
		objective.evaluate(level_value)

func get_objective_evaluation_result()-> Dictionary:
	if objectives.size() == 0:
		push_warning("Empty objective array on current level")
		return {ObjectiveResult.SCORE: 0, ObjectiveResult.COUNT: 0}
	var score: int = 0
	var count: int = 0
	for objective in objectives:
		if objective.is_complete:
			score += objective.score_value
			count += 1
	return {ObjectiveResult.SCORE: score, ObjectiveResult.COUNT: count}
