class_name TankManager

enum TankControllerType { PLAYER = 0, MULTIPLAYER = 1, AI = 2, DUMMY = 3 }

const TANK_ID_DEBUG_TANK: String = "debug_tank"
const TANK_ID_M4A1_SHERMAN: String = "m4a1_sherman"
const TANK_ID_TIGER_1: String = "tiger_1"

static var tank_specs: Dictionary[String, TankSpec] = {
	TANK_ID_DEBUG_TANK: preload("res://src/entities/tank/tanks/debug_tank/debug_tank.tres"),
	TANK_ID_M4A1_SHERMAN: preload("res://src/entities/tank/tanks/m4a1_sherman/m4a1_sherman.tres"),
	TANK_ID_TIGER_1: preload("res://src/entities/tank/tanks/tiger_1/tiger_1.tres"),
}
static var DummyTankControllerScene := preload(
	"res://src/controllers/dummy_tank_controller/dummy_tank_controller.tscn"
)
static var tank_controller_scenes: Dictionary[TankControllerType, PackedScene] = {
	TankControllerType.PLAYER:
	preload(
		"res://src/controllers/mobile_player_tank_controller/mobile_player_tank_controller.tscn"
	),
	TankControllerType.MULTIPLAYER: DummyTankControllerScene,
	TankControllerType.AI:
	preload("res://src/controllers/ai_tank_controller/ai_tank_controller.tscn"),
	TankControllerType.DUMMY: DummyTankControllerScene,
}

static var TankScene := preload("res://src/entities/tank/tank.tscn")


static func get_tank_ids() -> Array[String]:
	var tank_ids: Array[String] = []
	for tank_id: String in tank_specs.keys():
		tank_ids.append(tank_id)
	return tank_ids


static func create_tank(tank_id: String, tank_controller_type: TankControllerType) -> Tank:
	var is_player: bool = (
		tank_controller_type == TankControllerType.PLAYER
		or tank_controller_type == TankControllerType.MULTIPLAYER
	)
	var tank: Tank = TankScene.instantiate()
	var tank_spec: TankSpec = tank_specs.get(tank_id)
	assert(tank_spec != null, "Missing tank spec for tank_id=%s" % tank_id)
	tank.is_player = is_player
	tank.tank_spec = tank_spec
	tank.controller = tank_controller_scenes[tank_controller_type].instantiate()
	return tank
