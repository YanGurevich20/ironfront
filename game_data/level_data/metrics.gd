class_name Metrics extends Resource

const PLAYER_METRICS_PATH = "user://player_metrics.tres"

enum Metric {
	## game events
	KILLS,
	DEATHS,
	SHOTS_FIRED,
	SHOTS_HIT,
	SHOTS_MISSED,
	DAMAGE_TAKEN,
	DAMAGE_DEALT,

	## level end events
	RUN_TIME,
	DISTANCE_TRAVELED,
	OBJECTIVES_COMPLETED,
	SCORE_EARNED,
	STARS_EARNED,
	LEVELS_PLAYED
}

#TODO: Consider removing derived metrics from main metrics dictionary
var derived_metrics := {
	Metric.SHOTS_MISSED: func() -> void:
		metrics[Metric.SHOTS_MISSED] = metrics[Metric.SHOTS_FIRED] - metrics[Metric.SHOTS_HIT]
}

@export var metrics: Dictionary[Metric, int] = {
	Metric.KILLS: 0,
	Metric.DEATHS: 0,
	Metric.SHOTS_FIRED: 0,
	Metric.DAMAGE_DEALT: 0,
	Metric.SHOTS_HIT: 0,
	Metric.SHOTS_MISSED: 0,
	Metric.DAMAGE_TAKEN: 0,
	Metric.RUN_TIME: 0,
	Metric.DISTANCE_TRAVELED: 0,
	Metric.OBJECTIVES_COMPLETED: 0,
	Metric.SCORE_EARNED: 0,
	Metric.STARS_EARNED: 0,
	Metric.LEVELS_PLAYED: 0
}
#region Metric modification
# === Base Methods ===
func increment_metric(metric: Metric, amount: int = 1) -> void:
	_update_derived_metrics()
	metrics[metric] += amount

func increment_metrics(metrics_update: Dictionary[Metric, int]) -> void:
	for metric: Metric in metrics_update.keys():
		metrics[metric] += metrics_update[metric]
	_update_derived_metrics()

func set_metric(metric: Metric, amount: int = 1) -> void:
	_update_derived_metrics()
	metrics[metric] = amount

func set_metrics(metrics_update: Dictionary[Metric, int]) -> void:
	for metric: Metric in metrics_update.keys():
		metrics[metric] = metrics_update[metric]
	_update_derived_metrics()

#TODO: Consider less complex derived metrics update
func _update_derived_metrics() -> void :
	for metric: Metric in derived_metrics.keys():
		derived_metrics[metric].call()

func merge_metrics(source: Dictionary) -> void:
	for metric_key: Metric in source.keys():
		if metrics.has(metric_key): metrics[metric_key] += source[metric_key]
		else: metrics[metric_key] = source[metric_key]

func reset() -> void:
	for metric:Metric in metrics.keys():
		metrics[metric] = 0
	_update_derived_metrics()
	save()

#endregion

func save() -> void:
	ResourceSaver.save(self, PLAYER_METRICS_PATH)

static func load_or_create() -> Metrics:
	if ResourceLoader.exists(PLAYER_METRICS_PATH):
		var loaded :Metrics= load(PLAYER_METRICS_PATH)
		if loaded is Metrics:
			return loaded
	var new_progress := Metrics.new()
	new_progress._save_progress()
	return new_progress
