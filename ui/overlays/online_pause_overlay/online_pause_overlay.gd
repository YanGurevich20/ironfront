class_name OnlinePauseOverlay
extends BaseOverlay

signal settings_pressed
signal abort_pressed

@onready var settings_button: Button = %SettingsButton
@onready var abort_button: Button = %AbortButton


func _ready() -> void:
	super._ready()
	Utils.connect_checked(root_section.back_pressed, _on_root_back_pressed)
	Utils.connect_checked(settings_button.pressed, func() -> void: settings_pressed.emit())
	Utils.connect_checked(abort_button.pressed, func() -> void: abort_pressed.emit())


func _on_root_back_pressed(is_root_section: bool) -> void:
	if is_root_section:
		exit_overlay_pressed.emit()
