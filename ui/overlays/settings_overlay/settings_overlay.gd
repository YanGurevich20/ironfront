class_name SettingsOverlay extends BaseOverlay

const FEEDBACK_URL: String = "https://forms.gle/z8sPxvBqVqDKMbmk9"

signal reset_player_metrics_pressed
signal reset_game_progress_pressed

func _ready() -> void:
	super._ready()
	%DeveloperButton.pressed.connect(func()->void:show_only([$%DeveloperSection]))
	%FeedbackButton.pressed.connect(func()->void: OS.shell_open(FEEDBACK_URL))
	%VideoButton.pressed.connect(func()->void:show_only([$%VideoSection]))
	%AudioButton.pressed.connect(func()->void:show_only([$%AudioSection]))
	%ControlsButton.pressed.connect(func()->void:show_only([$%ControlsSection]))
	%AboutButton.pressed.connect(func()->void:show_only([$%AboutSection]))

	%ResetPlayerMetricsButton.pressed.connect(_on_reset_player_metrics_pressed)
	%ResetGameProgressButton.pressed.connect(_on_reset_game_progress_pressed)

func _on_reset_player_metrics_pressed()->void:
	reset_player_metrics_pressed.emit()
	_handle_back_pressed(false)

func _on_reset_game_progress_pressed()->void:
	reset_game_progress_pressed.emit()
	_handle_back_pressed(false)
