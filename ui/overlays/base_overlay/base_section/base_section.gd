class_name BaseSection extends VBoxContainer

@onready var BackButtonScene := preload("res://ui/overlays/base_overlay/base_section/back_button.tscn")

signal back_pressed(is_root: bool)
@export var is_root: bool = false
@export var add_back_button: bool = true
@export var back_button_label: String = "BACK" 

func _ready() -> void:
	if add_back_button:
		var back_button: Button = BackButtonScene.instantiate()
		back_button.text = back_button_label
		back_button.pressed.connect(func()->void: back_pressed.emit(is_root))
		add_child(back_button)
