class_name SettingsOverlay extends BaseOverlay

const FEEDBACK_URL: String = "https://forms.gle/z8sPxvBqVqDKMbmk9"
var settings_data: SettingsData

@onready var feedback_button: Button = %FeedbackButton

@onready var controls_opacity_slider: HSlider = %ControlsOpacitySlider
@onready var tank_hud_opacity_slider: HSlider = %TankHUDOpacitySlider
@onready var zoom_level_slider: HSlider = %ZoomLevelSlider
@onready var master_volume_slider: HSlider = %MasterVolumeSlider


func _ready() -> void:
	super._ready()
	Utils.connect_checked(root_section.back_pressed, _on_root_back_pressed)
	settings_data = SettingsData.get_instance()

	Utils.connect_checked(
		feedback_button.pressed,
		func() -> void:
			var open_result := OS.shell_open(FEEDBACK_URL)
			if open_result != OK:
				push_warning("Failed to open feedback URL: ", open_result)
	)
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

	zoom_level_slider.value = settings_data.zoom_level
	Utils.connect_checked(
		zoom_level_slider.value_changed,
		func(value: float) -> void: settings_data.zoom_level = value
	)

	master_volume_slider.value = settings_data.master_volume
	Utils.connect_checked(
		master_volume_slider.value_changed,
		func(value: float) -> void: settings_data.master_volume = value
	)


func _on_root_back_pressed(is_root_section: bool) -> void:
	if is_root_section:
		exit_overlay_pressed.emit()
