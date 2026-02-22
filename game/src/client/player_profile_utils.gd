class_name PlayerProfileUtils
extends RefCounted


static func create_local_player_tank(
	controller_type: TankManager.TankControllerType = TankManager.TankControllerType.PLAYER
) -> Tank:
	var selected_tank_spec: TankSpec = Account.loadout.selected_tank_spec
	print(
		(
			(
				"[client-profile] creating_local_tank"
				+ " username=%s tank_id=%s health=%d max_speed=%.2f accel=%.2f shells=%d"
			)
			% [
				Account.username,
				selected_tank_spec.tank_id if selected_tank_spec != null else "<null>",
				selected_tank_spec.health if selected_tank_spec != null else -1,
				selected_tank_spec.max_speed if selected_tank_spec != null else -1.0,
				selected_tank_spec.max_acceleration if selected_tank_spec != null else -1.0,
				selected_tank_spec.allowed_shells.size() if selected_tank_spec != null else -1,
			]
		)
	)
	var player_tank: Tank = TankManager.create_tank_from_spec(selected_tank_spec, controller_type)
	player_tank.display_player_name = Account.username
	return player_tank
