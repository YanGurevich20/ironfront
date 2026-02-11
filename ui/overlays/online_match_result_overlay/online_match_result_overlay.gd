class_name OnlineMatchResultOverlay
extends BaseOverlay

signal return_pressed

@onready var status_label: Label = %StatusLabel
@onready var return_button: Button = %ReturnButton


func _ready() -> void:
	super._ready()
	Utils.connect_checked(return_button.pressed, func() -> void: return_pressed.emit())


func display_match_end(status_message: String) -> void:
	status_label.text = status_message
