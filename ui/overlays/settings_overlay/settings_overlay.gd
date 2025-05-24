class_name SettingsOverlay extends BaseOverlay

const FEEDBACK_URL: String = "https://forms.gle/z8sPxvBqVqDKMbmk9"

@onready var feedback_button: Button = %FeedbackButton
@onready var video_button: Button = %VideoButton
@onready var audio_button: Button = %AudioButton
@onready var controls_button: Button = %ControlsButton
@onready var about_button: Button = %AboutButton

func _ready() -> void:
	super._ready()
	feedback_button.pressed.connect(func()->void: OS.shell_open(FEEDBACK_URL))
	video_button.pressed.connect(func()->void:show_only([%VideoSection]))
	audio_button.pressed.connect(func()->void:show_only([%AudioSection]))
	controls_button.pressed.connect(func()->void:show_only([%ControlsSection]))
	about_button.pressed.connect(func()->void:show_only([%AboutSection]))
