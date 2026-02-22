class_name EnemyIndicators extends Control

@export var arrow_texture: Texture2D
@export var edge_padding: float = 16.0

var _enemy_tanks_by_id: Dictionary[int, Tank] = {}
var _arrows_by_enemy_id: Dictionary[int, TextureRect] = {}


func _ready() -> void:
	Utils.connect_checked(get_tree().node_added, _on_node_added)
	Utils.connect_checked(get_tree().node_removed, _on_node_removed)


func _process(delta: float) -> void:
	if delta < 0.0:
		return
	if not visible:
		return
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var viewport_rect := Rect2(Vector2.ZERO, get_viewport_rect().size)
	var enemy_ids: Array[int] = _enemy_tanks_by_id.keys()

	if enemy_ids.is_empty():
		return

	for enemy_id: int in enemy_ids:
		var enemy_tank: Tank = _enemy_tanks_by_id.get(enemy_id)
		if enemy_tank == null or not is_instance_valid(enemy_tank):
			_remove_enemy(enemy_id)
			continue
		if not enemy_tank.is_inside_tree() or not enemy_tank.is_in_group("tank"):
			_remove_enemy(enemy_id)
			continue
		var screen_pos := _world_to_screen(camera, enemy_tank.global_position)
		if viewport_rect.has_point(screen_pos):
			var existing_arrow: TextureRect = _arrows_by_enemy_id.get(enemy_id)
			if existing_arrow != null:
				existing_arrow.hide()
			continue
		var direction := screen_pos - viewport_rect.size * 0.5
		var arrow: TextureRect = _arrows_by_enemy_id.get(enemy_id)
		if arrow == null:
			continue
		var edge_pos := _get_edge_position(viewport_rect, direction)
		arrow.rotation = direction.angle() + PI * 0.5
		arrow.position = edge_pos - arrow.pivot_offset
		arrow.show()


func _on_node_added(node: Node) -> void:
	if not visible:
		return
	var enemy_tank: Tank = node as Tank
	if enemy_tank == null:
		return
	_register_enemy(enemy_tank)


func _on_node_removed(node: Node) -> void:
	var enemy_tank: Tank = node as Tank
	if enemy_tank == null:
		return
	var enemy_id: int = enemy_tank.get_instance_id()
	_remove_enemy(enemy_id)


func reset_indicators() -> void:
	var enemy_ids: Array[int] = _enemy_tanks_by_id.keys()
	for enemy_id: int in enemy_ids:
		_remove_enemy(enemy_id)
	visible = false


func display_indicators() -> void:
	visible = true
	_register_current_enemies()


func _register_current_enemies() -> void:
	for node: Node in get_tree().get_nodes_in_group("tank"):
		var enemy_tank: Tank = node as Tank
		if enemy_tank == null:
			continue
		_register_enemy(enemy_tank)


func _register_enemy(enemy_tank: Tank) -> void:
	if enemy_tank.is_player or not enemy_tank.is_in_group("tank"):
		return
	var enemy_id: int = enemy_tank.get_instance_id()
	if _enemy_tanks_by_id.has(enemy_id):
		return
	_enemy_tanks_by_id[enemy_id] = enemy_tank
	var arrow := TextureRect.new()
	arrow.texture = arrow_texture
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	var arrow_size := Vector2(16.0, 16.0)
	if arrow_texture != null:
		arrow_size = arrow_texture.get_size()
	arrow.size = arrow_size
	arrow.pivot_offset = arrow_size * 0.5
	add_child(arrow)
	_arrows_by_enemy_id[enemy_id] = arrow
	enemy_tank.tree_exiting.connect(_on_enemy_tree_exiting.bind(enemy_id), CONNECT_ONE_SHOT)


func _on_enemy_tree_exiting(enemy_id: int) -> void:
	_remove_enemy(enemy_id)


func _remove_enemy(enemy_id: int) -> void:
	var arrow: TextureRect = _arrows_by_enemy_id.get(enemy_id)
	if arrow != null:
		arrow.queue_free()
	_arrows_by_enemy_id.erase(enemy_id)
	_enemy_tanks_by_id.erase(enemy_id)


func _get_edge_position(viewport_rect: Rect2, direction: Vector2) -> Vector2:
	var rect := Rect2(
		Vector2(edge_padding, edge_padding),
		viewport_rect.size - Vector2(edge_padding * 2.0, edge_padding * 2.0)
	)
	var center := viewport_rect.size * 0.5
	var dir := direction.normalized()
	var t_x: float = 1.0e20
	var t_y: float = 1.0e20
	if abs(dir.x) > 0.001:
		var target_x := rect.position.x if dir.x < 0.0 else rect.position.x + rect.size.x
		t_x = (target_x - center.x) / dir.x
	if abs(dir.y) > 0.001:
		var target_y := rect.position.y if dir.y < 0.0 else rect.position.y + rect.size.y
		t_y = (target_y - center.y) / dir.y
	var t: float = min(t_x, t_y)
	return center + dir * t


func _world_to_screen(camera: Camera2D, world_pos: Vector2) -> Vector2:
	var canvas_transform := camera.get_canvas_transform()
	return canvas_transform * world_pos
