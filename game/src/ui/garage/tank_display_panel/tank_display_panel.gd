class_name TankDisplayPanel extends Control

var account: Account = Account.get_instance()
var preferences: Preferences = Preferences.get_instance()

@onready var tank_display: TextureRect = %TankDisplay
@onready var username_label: Label = %UsernameLabel


func _ready() -> void:
	username_label.text = account.username
	Utils.connect_checked(
		account.username_updated,
		func(new_username: String) -> void: username_label.text = new_username
	)
	display_tank()
	Utils.connect_checked(
		preferences.selected_tank_id_updated, func(_tank_id: String) -> void: display_tank()
	)


func display_tank() -> void:
	var tank_spec: TankSpec = TankManager.tank_specs.get(preferences.selected_tank_id)
	if tank_spec == null:
		return
	tank_display.texture = tank_spec.preview_texture
