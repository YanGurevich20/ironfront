class_name PauseOverlay
extends BaseOverlay

signal settings_pressed

signal abort_pressed

var _pending_objectives: Array[Objective] = []

@onready var objectives_button: Button = %ObjectivesButton
@onready var settings_button: Button = %SettingsButton
@onready var abort_button: Button = %AbortButton
@onready var objectives_section: BaseSection = %ObjectivesSection
@onready var objectives_container: ObjectivesContainer = %ObjectivesContainer


func _ready() -> void:
	super._ready()
	Utils.connect_checked(root_section.back_pressed, _on_section_back_pressed)
	Utils.connect_checked(objectives_section.back_pressed, _on_section_back_pressed)
	# Show the objectives section and populate it when the user clicks the button
	Utils.connect_checked(
		objectives_button.pressed,
		func() -> void:
			if _pending_objectives.size() > 0:
				objectives_container.display_objectives(_pending_objectives)
			show_only([objectives_section])
	)
	Utils.connect_checked(settings_button.pressed, func() -> void: settings_pressed.emit())
	Utils.connect_checked(abort_button.pressed, func() -> void: abort_pressed.emit())


func set_objectives(new_objectives: Array[Objective]) -> void:
	# Defer rendering until the user actually opens the objectives section.
	_pending_objectives = new_objectives
	# If the objectives section is currently visible (user already opened it), refresh it immediately.
	if objectives_section.visible:
		objectives_container.display_objectives(_pending_objectives)


func _on_section_back_pressed(is_root_section: bool) -> void:
	if is_root_section:
		exit_overlay_pressed.emit()
		return
	show_only([root_section])
