class_name BaseSection
extends VBoxContainer

signal back_pressed(is_root: bool)

@export var is_root: bool = false
@export var add_back_button: bool = true
@export var back_button_label: String = "BACK"

@onready
var BackButtonScene := preload("res://src/ui/overlays/base_overlay/base_section/back_button.tscn")


func _ready() -> void:
	if add_back_button:
		var back_button: Button = BackButtonScene.instantiate()
		back_button.text = back_button_label
		Utils.connect_checked(back_button.pressed, func() -> void: back_pressed.emit(is_root))
		add_child(back_button)
