class_name MetricsOverlay extends BaseOverlay

@onready var metrics_list := $%MetricsList
@onready var MetricDisplayScene := preload("res://ui/overlays/metrics_overlay/metric_display/metric_display.tscn")
func _ready() -> void:
	super._ready()

func display_metrics(metrics:Dictionary) -> void:
	for child: Node in metrics_list.get_children():
		metrics_list.remove_child(child)
		child.queue_free()
	for metric: Metrics.Metric in metrics:
		var metric_display: MetricDisplay = MetricDisplayScene.instantiate()
		var metric_name: String = str(Metrics.Metric.keys()[metric]).capitalize()
		metric_display.metric_text = metric_name
		metric_display.value_text = str(metrics[metric])
		metrics_list.add_child(metric_display)
