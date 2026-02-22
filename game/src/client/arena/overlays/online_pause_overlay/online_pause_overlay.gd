class_name OnlinePauseOverlay
extends BaseOverlay

signal abort_pressed
signal logout_pressed
signal settings_pressed

@onready var abort_button: Button = %AbortButton
@onready var logout_button: Button = %LogoutButton
@onready var settings_button: Button = %SettingsButton


func _ready() -> void:
	super._ready()
	Utils.connect_checked(root_section.back_pressed, _on_root_back_pressed)
	Utils.connect_checked(abort_button.pressed, func() -> void: abort_pressed.emit())
	Utils.connect_checked(logout_button.pressed, func() -> void: logout_pressed.emit())
	Utils.connect_checked(settings_button.pressed, func() -> void: settings_pressed.emit())


func _on_root_back_pressed(is_root_section: bool) -> void:
	if is_root_section:
		exit_overlay_pressed.emit()
