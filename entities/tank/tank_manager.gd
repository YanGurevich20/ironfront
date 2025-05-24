class_name TankManager

static var CameraScene := preload("res://core/main_camera.tscn")

enum TankId {m4a1_sherman, tiger_1}
static var TANK_SPECS: Dictionary[TankId, TankSpec] = {
	TankId.m4a1_sherman: preload("res://entities/tank/tanks/m4a1_sherman/m4a1_sherman.tres"),
	TankId.tiger_1: preload("res://entities/tank/tanks/tiger_1/tiger_1.tres"),
}

enum TankControllerType {PLAYER, AI, DUMMY}
static var TANK_CONTROLLER_SCENES: Dictionary[TankControllerType, PackedScene] = {
	TankControllerType.PLAYER: preload("res://controllers/mobile_player_tank_controller/mobile_player_tank_controller.tscn"),
	TankControllerType.AI: preload("res://controllers/ai_tank_controller/ai_tank_controller.tscn"),
	TankControllerType.DUMMY: preload("res://controllers/dudmmy_tank_controller/dummy_tank_controller.tscn"),
}

static var TankScene := preload("res://entities/tank/tank.tscn")
static var DestroyedTankScene := preload("res://entities/destroyed_tank/destroyed_tank.tscn")

static func create_tank(tank_id: TankId, tank_controller_type: TankControllerType) -> Tank:
	var is_player: bool = tank_controller_type == TankControllerType.PLAYER
	var tank: Tank = TankScene.instantiate()
	tank.is_player = is_player
	tank.tank_spec = TANK_SPECS[tank_id]
	var tank_controller: Node = TANK_CONTROLLER_SCENES[tank_controller_type].instantiate()
	tank.add_child(tank_controller)
	if is_player:
		var camera: Camera2D = CameraScene.instantiate()
		tank.add_child(camera)
	return tank

static func create_destroyed_tank(tank: Tank) -> DestroyedTank:
	var destroyed_tank: DestroyedTank = DestroyedTankScene.instantiate()
	destroyed_tank.global_position = tank.global_position
	destroyed_tank.global_rotation = tank.global_rotation
	destroyed_tank.linear_velocity = tank.linear_velocity
	destroyed_tank.angular_velocity = tank.angular_velocity

	var tank_turret := tank.turret
	var destroyed_tank_turret := destroyed_tank.turret
	destroyed_tank_turret.rotation = tank_turret.rotation

	return destroyed_tank 