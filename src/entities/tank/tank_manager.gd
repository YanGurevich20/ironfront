class_name TankManager

enum TankId { DEBUG_TANK = -1, M4A1_SHERMAN = 0, TIGER_1 = 1 }
enum TankControllerType { PLAYER = 0, MULTIPLAYER = 1, AI = 2, DUMMY = 3 }

static var tank_specs: Dictionary[TankId, TankSpec] = {
	TankId.DEBUG_TANK: preload("res://src/entities/tank/tanks/debug_tank/debug_tank.tres"),
	TankId.M4A1_SHERMAN: preload("res://src/entities/tank/tanks/m4a1_sherman/m4a1_sherman.tres"),
	TankId.TIGER_1: preload("res://src/entities/tank/tanks/tiger_1/tiger_1.tres"),
}
static var tank_controller_scenes: Dictionary[TankControllerType, PackedScene] = {
	TankControllerType.PLAYER:
	preload(
		"res://src/controllers/mobile_player_tank_controller/mobile_player_tank_controller.tscn"
	),
	TankControllerType.MULTIPLAYER:
	preload("res://src/controllers/multiplayer_tank_controller/multiplayer_tank_controller.tscn"),
	TankControllerType.AI:
	preload("res://src/controllers/ai_tank_controller/ai_tank_controller.tscn"),
	TankControllerType.DUMMY:
	preload("res://src/controllers/dummy_tank_controller/dummy_tank_controller.tscn"),
}

static var TankScene := preload("res://src/entities/tank/tank.tscn")


static func create_tank(tank_id: TankId, tank_controller_type: TankControllerType) -> Tank:
	var is_player: bool = (
		tank_controller_type == TankControllerType.PLAYER
		or tank_controller_type == TankControllerType.MULTIPLAYER
	)
	var tank: Tank = TankScene.instantiate()
	tank.is_player = is_player
	tank.tank_spec = tank_specs[tank_id]
	tank.controller = tank_controller_scenes[tank_controller_type].instantiate()
	return tank
