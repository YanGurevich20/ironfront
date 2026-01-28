class_name LevelButton
extends Button

@export var level: int:
	get:
		return _level
	set(value):
		_level = value
		update_text()
@export var stars: int:
	get:
		return _stars
	set(value):
		_stars = value
		update_text()

var _level: int
var _stars: int


func update_text() -> void:
	text = "LEVEL %d (%d/3)" % [_level, _stars]
