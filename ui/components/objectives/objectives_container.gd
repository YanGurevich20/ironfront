# objectives_container.gd
class_name ObjectivesContainer extends Control

@onready var ObjectiveDisplayScene := preload("res://ui/components/objectives/objective_display.tscn")

func display_objectives(objectives: Array[Objective]) -> void:
	print("ObjectivesContainer.display_objectives called. size:", objectives.size())
	visible = objectives.size() > 0
	for objective_display in get_children():
		remove_child(objective_display)
		objective_display.queue_free()
	for objective in objectives:
		print("displaying objective: %s" % objective)
		var objective_display := ObjectiveDisplayScene.instantiate()
		objective_display.objective = objective
		add_child(objective_display)
