class_name PlayerProfileUtils
extends RefCounted


static func create_local_player_tank(
	controller_type: TankManager.TankControllerType = TankManager.TankControllerType.PLAYER
) -> Tank:
	var player_data: PlayerData = PlayerData.get_instance()
	var preferences: Preferences = Preferences.get_instance()
	var selected_tank_id: String = preferences.selected_tank_id
	var unlocked_tank_ids: Array[String] = player_data.get_unlocked_tank_ids()
	if not unlocked_tank_ids.has(selected_tank_id):
		if unlocked_tank_ids.size() > 0:
			selected_tank_id = unlocked_tank_ids[0]
		else:
			selected_tank_id = TankManager.TANK_ID_TIGER_1
	var player_tank: Tank = TankManager.create_tank(selected_tank_id, controller_type)
	player_tank.display_player_name = player_data.player_name.strip_edges()
	return player_tank
