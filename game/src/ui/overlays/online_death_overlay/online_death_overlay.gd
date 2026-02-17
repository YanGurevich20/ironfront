class_name OnlineDeathOverlay
extends BaseOverlay

signal respawn_pressed
signal return_pressed

@onready var respawn_button: Button = %RespawnButton
@onready var return_button: Button = %ReturnButton


func _ready() -> void:
	super._ready()
	Utils.connect_checked(respawn_button.pressed, func() -> void: respawn_pressed.emit())
	Utils.connect_checked(return_button.pressed, func() -> void: return_pressed.emit())
