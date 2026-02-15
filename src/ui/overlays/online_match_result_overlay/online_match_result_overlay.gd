class_name OnlineMatchResultOverlay
extends BaseOverlay

signal return_pressed

@onready var status_label: Label = %StatusLabel
@onready var kills_label: Label = %KillsLabel
@onready var reward_label: Label = %RewardLabel
@onready var return_button: Button = %ReturnButton


func _ready() -> void:
	super._ready()
	Utils.connect_checked(return_button.pressed, func() -> void: return_pressed.emit())


func display_match_end(summary: Dictionary) -> void:
	status_label.text = str(summary.get("status_message", "MATCH ENDED"))
	kills_label.text = "KILLS: %d" % int(summary.get("kills", 0))
	var reward_dollars: int = int(summary.get("reward_dollars", 0))
	reward_label.text = "REWARD: %s" % Utils.format_dollars(reward_dollars)
