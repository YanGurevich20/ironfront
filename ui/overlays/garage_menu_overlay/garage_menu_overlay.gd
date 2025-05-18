class_name GarageMenuOverlay extends BaseOverlay

signal settings_pressed
signal metrics_pressed

@onready var settings_button: Button = %SettingsButton
@onready var metrics_button: Button = %MetricsButton

func _ready() -> void:
	super._ready()
	
	settings_button.pressed.connect(func() -> void: settings_pressed.emit())
	
	metrics_button.pressed.connect(func() -> void: metrics_pressed.emit())
