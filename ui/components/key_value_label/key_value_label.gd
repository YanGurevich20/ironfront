class_name KeyValueLabel extends HBoxContainer

@onready var key_label:Label = $Key
@onready var value_label:Label = $Value

@export var key_text: String = "placeholder_key"
@export var value_text: String = "placeholder_value"

func _ready() -> void:
	key_label.text = key_text
	value_label.text = value_text
