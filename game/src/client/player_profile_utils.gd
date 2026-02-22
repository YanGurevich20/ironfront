class_name PlayerProfileUtils
extends RefCounted


static func create_local_player_tank(
	controller_type: TankManager.TankControllerType = TankManager.TankControllerType.PLAYER
) -> Tank:
	var selected_tank_id: String = Account.loadout.selected_tank_id
	if selected_tank_id.is_empty():
		selected_tank_id = TankManager.TANK_ID_M4A1_SHERMAN
	var player_tank: Tank = TankManager.create_tank(selected_tank_id, controller_type)
	player_tank.display_player_name = Account.username
	return player_tank
