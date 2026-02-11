class_name TankHUDLayer
extends Control

var tank_huds_by_tank: Dictionary[Tank, TankHUD] = {}

@onready var tank_hud_scene: PackedScene = preload("res://entities/tank/tank_hud/tank_hud.tscn")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Utils.connect_checked(GameplayBus.tank_destroyed, _on_tank_destroyed)


func _process(delta: float) -> void:
	if delta < 0.0 or not visible:
		return
	_sync_tank_huds()
	_update_tank_hud_positions()


func display_huds() -> void:
	visible = true
	_sync_tank_huds()
	_update_tank_hud_positions()


func reset_huds() -> void:
	var tracked_tanks: Array[Tank] = tank_huds_by_tank.keys()
	for tank: Tank in tracked_tanks:
		_remove_tank_hud(tank)
	visible = false


func _sync_tank_huds() -> void:
	var tracked_tanks: Array[Tank] = tank_huds_by_tank.keys()
	for tank: Tank in tracked_tanks:
		if not is_instance_valid(tank) or not tank.is_in_group("tank"):
			_remove_tank_hud(tank)

	for node: Node in get_tree().get_nodes_in_group("tank"):
		var tank: Tank = node as Tank
		if tank == null:
			continue
		if tank_huds_by_tank.has(tank):
			continue
		_create_tank_hud(tank)


func _create_tank_hud(tank: Tank) -> void:
	var tank_hud: TankHUD = tank_hud_scene.instantiate()
	add_child(tank_hud)
	tank_hud.initialize(tank)
	tank_hud.update_health_bar(tank._health)
	tank_huds_by_tank[tank] = tank_hud
	Utils.connect_checked(tank.health_updated, _on_tank_health_updated)
	Utils.connect_checked(tank.impact_result_received, _on_tank_impact_result_received)


func _remove_tank_hud(tank: Tank) -> void:
	var tank_hud: TankHUD = tank_huds_by_tank.get(tank)
	if tank_hud != null:
		tank_hud.queue_free()
	tank_huds_by_tank.erase(tank)
	if is_instance_valid(tank):
		if tank.health_updated.is_connected(_on_tank_health_updated):
			tank.health_updated.disconnect(_on_tank_health_updated)
		if tank.impact_result_received.is_connected(_on_tank_impact_result_received):
			tank.impact_result_received.disconnect(_on_tank_impact_result_received)


func _on_tank_destroyed(tank: Tank) -> void:
	if not tank_huds_by_tank.has(tank):
		return
	_remove_tank_hud(tank)


func _on_tank_health_updated(health: int, tank: Tank) -> void:
	var tank_hud: TankHUD = tank_huds_by_tank.get(tank)
	if tank_hud == null:
		return
	tank_hud.update_health_bar(health)


func _on_tank_impact_result_received(impact_result: ShellSpec.ImpactResult, tank: Tank) -> void:
	var tank_hud: TankHUD = tank_huds_by_tank.get(tank)
	if tank_hud == null:
		return
	tank_hud.handle_impact_result(impact_result)


func _update_tank_hud_positions() -> void:
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera == null:
		return
	for tank: Tank in tank_huds_by_tank.keys():
		var tank_hud: TankHUD = tank_huds_by_tank[tank]
		if tank_hud == null:
			continue
		tank_hud.update_health_bar(tank._health)
		tank_hud.global_position = _world_to_screen(camera, _get_hud_world_position(tank, tank_hud))
		tank_hud.rotation = 0.0


func _get_hud_world_position(tank: Tank, tank_hud: TankHUD) -> Vector2:
	var biggest_dimension: float = max(tank.tank_spec.hull_size.x, tank.tank_spec.hull_size.y)
	return tank.global_position - Vector2(tank_hud.size.x / 2, biggest_dimension)


func _world_to_screen(camera: Camera2D, world_position: Vector2) -> Vector2:
	return camera.get_canvas_transform() * world_position
