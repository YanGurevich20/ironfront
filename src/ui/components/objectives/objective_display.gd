class_name ObjectiveDisplay
extends Control

@export var objective: Objective

var progress_style := preload(
	"res://src/ui/components/objectives/progress_bar_fill_box_yellow.tres"
)

@onready var description_label: Label = $%DescriptionLabel
@onready var progress_bar: ProgressBar = $%ProgressBar


func _ready() -> void:
	description_label.text = objective.generate_description()
	var progress_ratio := objective.get_progress_ratio()
	progress_bar.value = progress_bar.max_value * progress_ratio
	if objective.is_complete:
		progress_bar.add_theme_stylebox_override("fill", progress_style)
