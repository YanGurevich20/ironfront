class_name TankDisplayPanel extends Control

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
		Account.loadout.selected_tank_id_updated, func(_tank_id: String) -> void: _display_tank()
	)


func _display_tank() -> void:
	var tank_id: String = Account.loadout.selected_tank_id
	var tank_spec: TankSpec = TankManager.tank_specs.get(tank_id, null)
	assert(tank_spec != null, "Missing tank spec for selected_tank_id=%s" % tank_id)
	tank_display.texture = tank_spec.preview_texture
