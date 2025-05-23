class_name SettingsOverlay extends BaseOverlay

const FEEDBACK_URL: String = "https://forms.gle/z8sPxvBqVqDKMbmk9"

func _ready() -> void:
	super._ready()
	%FeedbackButton.pressed.connect(func()->void: OS.shell_open(FEEDBACK_URL))
	%VideoButton.pressed.connect(func()->void:show_only([%VideoSection]))
	%AudioButton.pressed.connect(func()->void:show_only([%AudioSection]))
	%ControlsButton.pressed.connect(func()->void:show_only([%ControlsSection]))
	%AboutButton.pressed.connect(func()->void:show_only([%AboutSection]))
