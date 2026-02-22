class_name TankManager

enum TankControllerType { PLAYER = 0, MULTIPLAYER = 1, AI = 2, DUMMY = 3 }

const TANK_ID_M4A1_SHERMAN: String = "m4a1_sherman"
const TANK_ID_TIGER_1: String = "tiger_1"

static var tank_specs: Dictionary[String, TankSpec] = {
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


static func find_tank_spec(tank_id: String) -> TankSpec:
	return tank_specs.get(tank_id, null)


static func require_tank_spec(tank_id: String) -> TankSpec:
	var spec: TankSpec = find_tank_spec(tank_id)
	assert(spec != null, "TankManager: missing tank spec for tank_id=%s" % tank_id)
	return spec


static func create_tank_from_spec(
	tank_spec: TankSpec, tank_controller_type: TankControllerType
) -> Tank:
	assert(tank_spec != null, "TankManager: create_tank_from_spec received null tank_spec")
	var is_player: bool = (
		tank_controller_type == TankControllerType.PLAYER
		or tank_controller_type == TankControllerType.MULTIPLAYER
	)
	var tank: Tank = TankScene.instantiate()
	tank.is_player = is_player
	tank.tank_spec = tank_spec
	tank.controller = tank_controller_scenes[tank_controller_type].instantiate()
	return tank


static func create_tank(tank_id: String, tank_controller_type: TankControllerType) -> Tank:
	var tank_spec: TankSpec = require_tank_spec(tank_id)
	return create_tank_from_spec(tank_spec, tank_controller_type)
