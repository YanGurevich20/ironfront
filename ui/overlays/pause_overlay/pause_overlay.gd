class_name PauseOverlay extends BaseOverlay

@onready var objectives_button: Button = %ObjectivesButton
@onready var settings_button: Button = %SettingsButton
@onready var abort_button :Button = %AbortButton
@onready var objectives_section: BaseSection = %ObjectivesSection
@onready var objectives_container: ObjectivesContainer = %ObjectivesContainer

signal settings_pressed
signal abort_pressed

# Store the latest objectives so we can render them when the user asks to
var _pending_objectives: Array[Objective] = []

func _ready() -> void:
	super._ready()
	# Show the objectives section and populate it when the user clicks the button
	objectives_button.pressed.connect(func()->void:
		if _pending_objectives.size() > 0:
			objectives_container.display_objectives(_pending_objectives)
		show_only([objectives_section])
	)
	settings_button.pressed.connect(func()->void: settings_pressed.emit())
	abort_button.pressed.connect(func()->void: abort_pressed.emit())

func set_objectives(new_objectives: Array[Objective]) -> void:
	# Defer rendering until the user actually opens the objectives section.
	_pending_objectives = new_objectives
	# If the objectives section is currently visible (user already opened it), refresh it immediately.
	if objectives_section.visible:
		objectives_container.display_objectives(_pending_objectives)
