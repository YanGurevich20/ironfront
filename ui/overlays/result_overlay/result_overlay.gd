class_name ResultOverlay extends BaseOverlay

@onready var result_label: Label = %ResultLabel
@onready var score_label: Label = %ScoreLabel
@onready var stars_label: Label = %StarsLabel
@onready var time_label: Label = %TimeLabel
@onready var retry_button: Button = %RetryButton
@onready var objectives_button: Button = %ObjectivesButton
@onready var objectives_container: ObjectivesContainer = $%ObjectivesContainer

signal retry_pressed

func _ready() -> void:
	super._ready()
	retry_button.pressed.connect(func()->void: retry_pressed.emit())

func display_result(success: bool, metrics: Dictionary[Metrics.Metric, int], objectives: Array[Objective]) -> void:
	result_label.text = "VICTORY!" if success else "DEFEAT!"
	score_label.text = "SCORE: %d POINTS" % metrics[Metrics.Metric.SCORE_EARNED]
	stars_label.text = "STARS: %d/3" % metrics[Metrics.Metric.STARS_EARNED]
	time_label.text = "TIME: " + Utils.format_seconds(metrics[Metrics.Metric.RUN_TIME])
	objectives_button.pressed.connect(func()->void: display_objectives(objectives))

func display_objectives(objectives: Array[Objective]) -> void:
	objectives_container.display_objectives(objectives)
	show_only([objectives_container])
