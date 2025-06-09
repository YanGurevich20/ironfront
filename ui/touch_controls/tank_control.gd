class_name TankControl extends Control

@onready var left_lever :Lever= $LeftLever
@onready var right_lever :Lever= $RightLever
@onready var traverse_wheel :TraverseWheel= $TraverseWheel
@onready var fire_button: FireButton = $FireButton
@onready var shell_select: ShellSelect = % ShellSelect

@onready var pause_button: Button = %PauseButton
@onready var zoom_slider: HSlider = %ZoomSlider

var settings_data: SettingsData

func _ready() -> void:
	settings_data = SettingsData.get_instance()
	fire_button.fire_button_pressed.connect(func() -> void: SignalBus.fire_input.emit())
	pause_button.pressed.connect(func() -> void: SignalBus.pause_input.emit())
	zoom_slider.value_changed.connect(func(value: float) -> void: settings_data.zoom_level = value)
	SignalBus.settings_changed.connect(_apply_settings)
	_apply_settings()

func _apply_settings() -> void:
	modulate.a = settings_data.controls_opacity
	zoom_slider.value = settings_data.zoom_level

func reset_input() -> void:
	left_lever.reset_input()
	right_lever.reset_input()
	traverse_wheel.reset_input()
	fire_button.reset_input()

func display_controls() -> void:
	shell_select.initialize()
