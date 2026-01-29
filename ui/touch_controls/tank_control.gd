class_name TankControl
extends Control

@onready var left_lever: Lever = $LeftLever
@onready var right_lever: Lever = $RightLever
@onready var traverse_wheel: TraverseWheel = $TraverseWheel
@onready var fire_button: FireButton = %FireButton
@onready var shell_select: ShellSelect = %ShellSelect
@onready var pause_button: Button = %PauseButton
@onready var zoom_slider: HSlider = %ZoomSlider


func _ready() -> void:
	Utils.connect_checked(
		fire_button.fire_button_pressed, func() -> void: SignalBus.fire_input.emit()
	)
	Utils.connect_checked(pause_button.pressed, func() -> void: SignalBus.pause_input.emit())
	Utils.connect_checked(
		zoom_slider.value_changed, func(value: float) -> void: _set_zoom_level(value)
	)
	_apply_settings()
	Utils.connect_checked(SignalBus.settings_changed, _apply_settings)


func _apply_settings() -> void:
	var settings_data: SettingsData = SettingsData.get_instance()
	modulate.a = settings_data.controls_opacity
	zoom_slider.set_value_no_signal(settings_data.zoom_level)


func _set_zoom_level(value: float) -> void:
	var settings_data: SettingsData = SettingsData.get_instance()
	settings_data.zoom_level = value


func reset_input() -> void:
	left_lever.reset_input()
	right_lever.reset_input()
	traverse_wheel.reset_input()
	fire_button.reset_input()


func display_controls() -> void:
	shell_select.initialize()
