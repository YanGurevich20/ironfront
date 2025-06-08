class_name TankManager

enum TankId {DEBUG_TANK, M4A1_SHERMAN, TIGER_1}
static var TANK_SPECS: Dictionary[TankId, TankSpec] = {
	TankId.DEBUG_TANK: preload("res://entities/tank/tanks/debug_tank/debug_tank.tres"),
	TankId.M4A1_SHERMAN: preload("res://entities/tank/tanks/m4a1_sherman/m4a1_sherman.tres"),
	TankId.TIGER_1: preload("res://entities/tank/tanks/tiger_1/tiger_1.tres"),
}

enum TankControllerType {PLAYER, AI, DUMMY}
static var TANK_CONTROLLER_SCENES: Dictionary[TankControllerType, PackedScene] = {
	TankControllerType.PLAYER: preload("res://controllers/mobile_player_tank_controller/mobile_player_tank_controller.tscn"),
	TankControllerType.AI: preload("res://controllers/ai_tank_controller/ai_tank_controller.tscn"),
	TankControllerType.DUMMY: preload("res://controllers/dudmmy_tank_controller/dummy_tank_controller.tscn"),
}

static var TankScene := preload("res://entities/tank/tank.tscn")
static func create_tank(tank_id: TankId, tank_controller_type: TankControllerType) -> Tank:
	var is_player: bool = tank_controller_type == TankControllerType.PLAYER
	var tank: Tank = TankScene.instantiate()
	tank.is_player = is_player
	tank.tank_spec = TANK_SPECS[tank_id]
	tank.controller = TANK_CONTROLLER_SCENES[tank_controller_type].instantiate()
	return tank