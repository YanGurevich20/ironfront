class_name LoginMenu extends Control

signal play_pressed
signal login_pressed

@onready var play_button: Button = $%PlayButton
@onready var login_button: Button = $%LoginButton

func _ready() -> void:
	play_button.pressed.connect(func()->void:play_pressed.emit())
	login_button.pressed.connect(func()->void:login_pressed.emit())
