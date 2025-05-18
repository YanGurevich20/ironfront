class_name PauseOverlay extends BaseOverlay

@onready var objectives_button: Button = $%ObjectivesButton
@onready var settings_button: Button = $%SettingsButton
@onready var abort_button :Button = $%AbortButton
@onready var objectives_container := $%ObjectivesContainer

signal settings_pressed
signal abort_pressed

func _ready() -> void:
	super._ready()
	objectives_button.pressed.connect(func()->void: show_only([objectives_container]))
	settings_button.pressed.connect(func()->void: settings_pressed.emit())
	abort_button.pressed.connect(func()->void: abort_pressed.emit())

func set_objectives(new_objectives: Array[Objective]) -> void:
	if is_inside_tree(): objectives_container.display_objectives(new_objectives)
