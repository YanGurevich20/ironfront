class_name MetricDisplay
extends Control

@export var metric_text: String = "placeholder_metric"
@export var value_text: String = "placeholder_value"

@onready var metric_label: Label = %Metric
@onready var value_label: Label = %Value


func _ready() -> void:
	metric_label.text = metric_text
	value_label.text = value_text
