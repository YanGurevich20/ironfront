class_name TankDisplayPanel extends Control

@onready var tank_display: TextureRect = %TankDisplay

func display_tank(tank_id: TankManager.TankId) -> void:
	var tank_spec: TankSpec = TankManager.get_tank_spec(tank_id)
	tank_display.texture = tank_spec.preview_texture
