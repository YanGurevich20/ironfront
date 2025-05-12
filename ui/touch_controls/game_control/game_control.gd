extends Control

@onready var pause_button := $PauseButton

signal pause_pressed
func _ready() -> void:
	pause_button.pressed.connect(_on_pause_pressed)

func _on_pause_pressed() -> void:
	pause_pressed.emit()
