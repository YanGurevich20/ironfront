class_name TankDisplayPanel extends Control

@onready var tank_display: TextureRect = %TankDisplay

func display_tank(player_data: PlayerData) -> void:
	if not player_data.is_selected_tank_valid(): return
	var tank_spec: TankSpec = TankManager.TANK_SPECS[player_data.selected_tank_id]
	tank_display.texture = tank_spec.preview_texture
