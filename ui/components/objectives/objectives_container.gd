# objectives_container.gd
class_name ObjectivesContainer extends MarginContainer

@onready var ObjectiveDisplayScene := preload("res://ui/components/objectives/objective_display.tscn")
@onready var objective_list := $VBoxContainer/ObjectiveList

func display_objectives(objectives: Array[Objective]) -> void:
	visible = objectives.size() > 0
	for objective_display in objective_list.get_children():
		objective_list.remove_child(objective_display)
		objective_display.queue_free()
	for objective in objectives:
		var objective_display := ObjectiveDisplayScene.instantiate()
		objective_display.objective = objective
		objective_list.add_child(objective_display)
