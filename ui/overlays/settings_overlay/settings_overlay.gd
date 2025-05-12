class_name SettingsOverlay extends BaseOverlay

signal reset_player_metrics_pressed
signal reset_game_progress_pressed

func _ready() -> void:
	super._ready()
	$%DeveloperButton.pressed.connect(func()->void:show_only([$%DeveloperSection]))
	$%VideoButton.pressed.connect(func()->void:show_only([$%VideoSection]))
	$%AudioButton.pressed.connect(func()->void:show_only([$%AudioSection]))
	$%ControlsButton.pressed.connect(func()->void:show_only([$%ControlsSection]))
	$%AboutButton.pressed.connect(func()->void:show_only([$%AboutSection]))

	#TODO: Consider creating a settings manager class
	$%ResetPlayerMetricsButton.pressed.connect(_on_reset_player_metrics_pressed)
	$%ResetGameProgressButton.pressed.connect(_on_reset_game_progress_pressed)

func _on_reset_player_metrics_pressed()->void:
	reset_player_metrics_pressed.emit()
	_handle_back_pressed(false)

func _on_reset_game_progress_pressed()->void:
	reset_game_progress_pressed.emit()
	_handle_back_pressed(false)
