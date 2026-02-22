class_name PlayerProfileUtils
extends RefCounted


static func create_local_player_tank(
	controller_type: TankManager.TankControllerType = TankManager.TankControllerType.PLAYER
) -> Tank:
	var selected_tank_spec: TankSpec = Account.loadout.selected_tank_spec
	var player_tank: Tank = TankManager.create_tank_from_spec(selected_tank_spec, controller_type)
	player_tank.display_player_name = Account.username
	return player_tank
