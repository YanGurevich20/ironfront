class_name TankDisplayPanel
extends Control

@onready var tank_display: TextureRect = %TankDisplay
@onready var username_label: Label = %UsernameLabel


func _ready() -> void:
	username_label.text = Account.username
	Utils.connect_checked(
		Account.username_updated,
		func(new_username: String) -> void: username_label.text = new_username
	)
	_display_tank()
	Utils.connect_checked(
		Account.loadout.selected_tank_spec_updated, func(_spec: TankSpec) -> void: _display_tank()
	)


func _display_tank() -> void:
	tank_display.texture = Account.loadout.selected_tank_spec.preview_texture
