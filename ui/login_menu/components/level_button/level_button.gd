extends Button
class_name LevelButton
@export var level := 1
@export var stars := 0

signal level_pressed(level: int)

func _ready() -> void:
	text = "LEVEL %d (%d/3)" % [level, stars]
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	level_pressed.emit(level)
