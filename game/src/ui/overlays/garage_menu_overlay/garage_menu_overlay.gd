class_name GarageMenuOverlay extends BaseOverlay

signal settings_pressed

@onready var settings_button: Button = %SettingsButton
@onready var log_out_button: Button = %LogOutButton
@onready var quit_button: Button = %QuitButton


func _ready() -> void:
	super._ready()
	Utils.connect_checked(root_section.back_pressed, _on_root_back_pressed)

	Utils.connect_checked(settings_button.pressed, func() -> void: settings_pressed.emit())
	Utils.connect_checked(log_out_button.pressed, func() -> void: UiBus.log_out_pressed.emit())
	Utils.connect_checked(quit_button.pressed, func() -> void: UiBus.quit_pressed.emit())


func _on_root_back_pressed(is_root_section: bool) -> void:
	if is_root_section:
		exit_overlay_pressed.emit()
