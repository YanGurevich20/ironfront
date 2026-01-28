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
@onready var master_volume_slider: HSlider = %MasterVolumeSlider


func _ready() -> void:
	super._ready()
	settings_data = SettingsData.get_instance()

	Utils.connect_checked(
		feedback_button.pressed,
		func() -> void:
			var open_result := OS.shell_open(FEEDBACK_URL)
			if open_result != OK:
				push_warning("Failed to open feedback URL: ", open_result)
	)
	Utils.connect_checked(video_button.pressed, func() -> void: show_only([%VideoSection]))
	Utils.connect_checked(audio_button.pressed, func() -> void: show_only([%AudioSection]))
	Utils.connect_checked(hud_button.pressed, func() -> void: show_only([%HUDSection]))
	Utils.connect_checked(about_button.pressed, func() -> void: show_only([%AboutSection]))

	controls_opacity_slider.value = settings_data.controls_opacity
	Utils.connect_checked(
		controls_opacity_slider.value_changed,
		func(value: float) -> void: settings_data.controls_opacity = value
	)

	tank_hud_opacity_slider.value = settings_data.tank_hud_opacity
	Utils.connect_checked(
		tank_hud_opacity_slider.value_changed,
		func(value: float) -> void: settings_data.tank_hud_opacity = value
	)

	master_volume_slider.value = settings_data.master_volume
	Utils.connect_checked(
		master_volume_slider.value_changed,
		func(value: float) -> void: settings_data.master_volume = value
	)
