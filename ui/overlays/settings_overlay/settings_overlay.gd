class_name SettingsOverlay extends BaseOverlay

const FEEDBACK_URL: String = "https://forms.gle/z8sPxvBqVqDKMbmk9"
var settings_data: SettingsData

@onready var feedback_button: Button = %FeedbackButton
@onready var video_button: Button = %VideoButton
@onready var audio_button: Button = %AudioButton
@onready var hud_button: Button = %HUDButton
@onready var about_button: Button = %AboutButton

@onready var controls_opacity_slider: HSlider = %ControlsOpacitySlider
@onready var tank_hud_opacity_slider: HSlider = %TankHUDOpacitySlider

func _ready() -> void:
	super._ready()
	settings_data = SettingsData.get_instance()
	
	feedback_button.pressed.connect(func()->void: OS.shell_open(FEEDBACK_URL))
	video_button.pressed.connect(func()->void:show_only([%VideoSection]))
	audio_button.pressed.connect(func()->void:show_only([%AudioSection]))
	hud_button.pressed.connect(func()->void:show_only([%HUDSection]))
	about_button.pressed.connect(func()->void:show_only([%AboutSection]))

	controls_opacity_slider.value = settings_data.controls_opacity
	controls_opacity_slider.value_changed.connect(func(value: float) -> void: settings_data.controls_opacity = value)

	tank_hud_opacity_slider.value = settings_data.tank_hud_opacity
	tank_hud_opacity_slider.value_changed.connect(func(value: float) -> void: settings_data.tank_hud_opacity = value)
