class_name GarageMenuOverlay extends BaseOverlay

signal settings_pressed
signal metrics_pressed

@onready var settings_button: Button = %SettingsButton
@onready var metrics_button: Button = %MetricsButton
@onready var log_out_button: Button = %LogOutButton
@onready var quit_button: Button = %QuitButton
func _ready() -> void:
	super._ready()
	
	settings_button.pressed.connect(func() -> void: settings_pressed.emit())
	metrics_button.pressed.connect(func() -> void: metrics_pressed.emit())
	log_out_button.pressed.connect(func() -> void: SignalBus.log_out_pressed.emit())
	quit_button.pressed.connect(func() -> void: SignalBus.quit_pressed.emit())
