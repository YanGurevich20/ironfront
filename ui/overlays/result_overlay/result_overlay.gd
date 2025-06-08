class_name ResultOverlay extends BaseOverlay

@onready var result_label: Label = %ResultLabel
@onready var score_label: Label = %ScoreLabel
@onready var stars_label: Label = %StarsLabel
@onready var time_label: Label = %TimeLabel
@onready var reward_label: Label = %RewardLabel
@onready var high_score_label: Label = %HighScoreLabel
@onready var retry_button: Button = %RetryButton
@onready var objectives_button: Button = %ObjectivesButton
@onready var objectives_container: ObjectivesContainer = $%ObjectivesContainer
@onready var objectives_section := $"PanelContainer/SectionsContainer/ObjectivesSection"

signal retry_pressed

func _ready() -> void:
	super._ready()
	retry_button.pressed.connect(func()->void:
		print("retry pressed result overlay")
		retry_pressed.emit())
	objectives_button.pressed.connect(_on_objectives_button_pressed)

func display_result(success: bool, metrics: Dictionary[Metrics.Metric, int], objectives: Array[Objective], reward_info: Game.RewardInfo) -> void:
	result_label.text = "VICTORY!" if success else "DEFEAT!"
	score_label.text = "SCORE: %d POINTS" % metrics[Metrics.Metric.SCORE_EARNED]
	stars_label.text = "STARS: %d/3" % metrics[Metrics.Metric.STARS_EARNED]
	time_label.text = "TIME: " + Utils.format_seconds(metrics[Metrics.Metric.RUN_TIME])
	reward_label.text = "REWARD: %s" % Utils.format_dollars(reward_info.total_reward)
	
	# Display doubled reward information
	if reward_info.doubled_stars.size() > 0:
		var doubled_text := "FIRST TIME BONUS! 2X REWARD FOR STAR"
		if reward_info.doubled_stars.size() == 1:
			doubled_text += " %d" % reward_info.doubled_stars[0]
		else:
			doubled_text += "S: " + ", ".join(reward_info.doubled_stars.map(func(s: int) -> String: return str(s)))
		high_score_label.text = doubled_text
		high_score_label.visible = true
	else:
		high_score_label.text = ""
		high_score_label.visible = false
	
	_stored_objectives = objectives

var _stored_objectives: Array[Objective] = []

func _on_objectives_button_pressed() -> void:
	display_objectives(_stored_objectives)

func display_objectives(objectives: Array[Objective]) -> void:
	objectives_container.display_objectives(objectives)
	show_only([objectives_section])
