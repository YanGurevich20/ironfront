class_name MetricsOverlay extends BaseOverlay

@onready var metrics_list := $%MetricsList
@onready var KeyValueLabelScene := preload("res://ui/components/key_value_label/key_value_label.tscn")
func _ready() -> void:
	super._ready()

func display_metrics(metrics:Dictionary) -> void:
	for child: Node in metrics_list.get_children():
		metrics_list.remove_child(child)
		child.queue_free()
	for key: Metrics.Metric in metrics:
		var key_value_label :KeyValueLabel= KeyValueLabelScene.instantiate()
		key_value_label.key_text = str(Metrics.Metric.find_key(key)).capitalize()
		key_value_label.value_text = str(metrics[key])
		metrics_list.add_child(key_value_label)
