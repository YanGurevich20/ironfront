class_name BaseSection extends VBoxContainer

signal back_pressed(is_root: bool)
@export var is_root: bool = false
@export var add_back_button: bool = true
@export var back_button_label: String = "BACK"

func _ready() -> void:
	var back_button := find_child("BackButton")
	back_button.text = back_button_label
	back_button.pressed.connect(func()->void: back_pressed.emit(is_root))
