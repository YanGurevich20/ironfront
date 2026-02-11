class_name ResultOverlay
extends BaseOverlay

signal retry_pressed

var _stored_objectives: Array[Objective] = []

@onready var result_label: Label = %ResultLabel
@onready var score_label: Label = %ScoreLabel
@onready var stars_label: Label = %StarsLabel
@onready var time_label: Label = %TimeLabel
@onready var reward_label: Label = %RewardLabel
@onready var high_score_label: Label = %HighScoreLabel
@onready var retry_button: Button = %RetryButton
@onready var objectives_button: Button = %ObjectivesButton
@onready var objectives_container: ObjectivesContainer = $%ObjectivesContainer
@onready var objectives_section: BaseSection = %ObjectivesSection


func _ready() -> void:
	super._ready()
	Utils.connect_checked(root_section.back_pressed, _on_section_back_pressed)
	Utils.connect_checked(objectives_section.back_pressed, _on_section_back_pressed)
	Utils.connect_checked(
		retry_button.pressed,
		func() -> void:
			print("retry pressed result overlay")
			retry_pressed.emit()
	)
	Utils.connect_checked(objectives_button.pressed, _on_objectives_button_pressed)


func display_result(
	success: bool,
	metrics: Dictionary[Metrics.Metric, int],
	objectives: Array[Objective],
	reward_info: Dictionary
) -> void:
	result_label.text = "VICTORY!" if success else "DEFEAT!"
	score_label.text = "SCORE: %d POINTS" % metrics[Metrics.Metric.SCORE_EARNED]
	stars_label.text = "STARS: %d/3" % metrics[Metrics.Metric.STARS_EARNED]
	time_label.text = "TIME: " + Utils.format_seconds(metrics[Metrics.Metric.RUN_TIME])
	var total_reward: int = int(reward_info.get("total_reward", 0))
	var doubled_stars_raw: Array = reward_info.get("doubled_stars", [])
	var doubled_stars: Array[int] = []
	for doubled_star_variant: Variant in doubled_stars_raw:
		doubled_stars.append(int(doubled_star_variant))
	reward_label.text = "REWARD: %s" % Utils.format_dollars(total_reward)

	# Display doubled reward information
	if doubled_stars.size() > 0:
		var doubled_text := "FIRST TIME BONUS! 2X REWARD FOR STAR"
		if doubled_stars.size() == 1:
			doubled_text += " %d" % doubled_stars[0]
		else:
			doubled_text += (
				"S: " + ", ".join(doubled_stars.map(func(s: int) -> String: return str(s)))
			)
		high_score_label.text = doubled_text
		high_score_label.visible = true
	else:
		high_score_label.text = ""
		high_score_label.visible = false

	_stored_objectives = objectives


func _on_objectives_button_pressed() -> void:
	display_objectives(_stored_objectives)


func display_objectives(objectives: Array[Objective]) -> void:
	objectives_container.display_objectives(objectives)
	show_only([objectives_section])


func _on_section_back_pressed(is_root_section: bool) -> void:
	if is_root_section:
		exit_overlay_pressed.emit()
		return
	show_only([root_section])
