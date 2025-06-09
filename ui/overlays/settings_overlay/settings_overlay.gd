class_name SettingsOverlay extends BaseOverlay

const FEEDBACK_URL: String = "https://forms.gle/z8sPxvBqVqDKMbmk9"
var settings_data: SettingsData = SettingsData.get_instance()

@onready var feedback_button: Button = %FeedbackButton
@onready var video_button: Button = %VideoButton
@onready var audio_button: Button = %AudioButton
@onready var controls_button: Button = %ControlsButton
@onready var about_button: Button = %AboutButton

@onready var controls_opacity_slider: HSlider = %ControlsOpacitySlider

func _ready() -> void:
	super._ready()
	feedback_button.pressed.connect(func()->void: OS.shell_open(FEEDBACK_URL))
	video_button.pressed.connect(func()->void:show_only([%VideoSection]))
	audio_button.pressed.connect(func()->void:show_only([%AudioSection]))
	controls_button.pressed.connect(func()->void:show_only([%ControlsSection]))
	about_button.pressed.connect(func()->void:show_only([%AboutSection]))

	controls_opacity_slider.value = settings_data.controls_opacity
	controls_opacity_slider.value_changed.connect(func(value: float) -> void: settings_data.controls_opacity = value)
