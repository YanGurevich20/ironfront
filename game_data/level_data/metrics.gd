class_name Metrics extends LoadableData

enum Metric {
	# game events
	KILLS,
	DEATHS,
	SHOTS_FIRED,
	SHOTS_HIT,
	SHOTS_MISSED,
	DAMAGE_TAKEN,
	DAMAGE_DEALT,

	# level end events
	RUN_TIME,
	DISTANCE_TRAVELED,
	OBJECTIVES_COMPLETED,
	SCORE_EARNED,
	STARS_EARNED,
	LEVELS_PLAYED
}

@export var metrics: Dictionary[Metric, int] = {
	Metric.KILLS: 0,
	Metric.DEATHS: 0,
	Metric.SHOTS_FIRED: 0,
	Metric.SHOTS_HIT: 0,
	Metric.SHOTS_MISSED: 0,
	Metric.DAMAGE_TAKEN: 0,
	Metric.DAMAGE_DEALT: 0,
	Metric.RUN_TIME: 0,
	Metric.DISTANCE_TRAVELED: 0,
	Metric.OBJECTIVES_COMPLETED: 0,
	Metric.SCORE_EARNED: 0,
	Metric.STARS_EARNED: 0,
	Metric.LEVELS_PLAYED: 0
}

var derived_metrics :Dictionary[Metric, Callable] = {
	Metric.SHOTS_MISSED: func() -> void:
		metrics[Metric.SHOTS_MISSED] = metrics[Metric.SHOTS_FIRED] - metrics[Metric.SHOTS_HIT]
}

static func get_instance() -> Metrics:
	return LoadableData.get_loadable_instance(Metrics)

func get_file_name() -> String:
	return "metrics"

#region Metric Modification
func increment_metric(metric: Metric, amount: int = 1) -> void:
	metrics[metric] += amount
	_update_derived_metrics()

func increment_metrics(metrics_update: Dictionary[Metric, int]) -> void:
	for metric: Metric in metrics_update.keys():
		metrics[metric] += metrics_update[metric]
	_update_derived_metrics()

func set_metric(metric: Metric, amount: int = 1) -> void:
	metrics[metric] = amount
	_update_derived_metrics()

func set_metrics(metrics_update: Dictionary[Metric, int]) -> void:
	for metric: Metric in metrics_update.keys():
		metrics[metric] = metrics_update[metric]
	_update_derived_metrics()

func merge_metrics(source: Dictionary) -> void:
	for metric_key: Metric in source.keys():
		if metrics.has(metric_key):
			metrics[metric_key] += source[metric_key]
		else:
			metrics[metric_key] = source[metric_key]
	_update_derived_metrics()

#endregion

func _update_derived_metrics() -> void:
	for metric: Metric in derived_metrics.keys():
		derived_metrics[metric].call()

