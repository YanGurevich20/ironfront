class_name EnemyIndicators extends Control

@export var arrow_texture: Texture2D
@export var edge_padding: float = 16.0

var _arrows: Dictionary = {}


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		_hide_all_arrows()
		return

	var viewport_rect := Rect2(Vector2.ZERO, get_viewport_rect().size)
	var enemies: Array[Tank] = _get_enemy_tanks()
	_prune_missing_arrows(enemies)

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var screen_pos := _world_to_screen(camera, enemy.global_position)
		if viewport_rect.has_point(screen_pos):
			_set_arrow_visible(enemy, false)
			continue
		var direction := screen_pos - viewport_rect.size * 0.5
		if direction.length_squared() < 0.001:
			_set_arrow_visible(enemy, false)
			continue
		var arrow := _get_or_create_arrow(enemy)
		var edge_pos := _get_edge_position(viewport_rect, direction)
		arrow.rotation = direction.angle() + PI * 0.5
		arrow.position = edge_pos - arrow.pivot_offset
		arrow.show()


func _get_enemy_tanks() -> Array[Tank]:
	var enemies: Array[Tank] = []
	for node: Node in get_tree().get_nodes_in_group("tank"):
		var tank := node as Tank
		if tank == null:
			continue
		if not tank.is_player:
			enemies.append(tank)
	return enemies


func _get_or_create_arrow(enemy: Tank) -> TextureRect:
	if _arrows.has(enemy):
		return _arrows[enemy]

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
	_arrows[enemy] = arrow
	return arrow


func _prune_missing_arrows(enemies: Array[Tank]) -> void:
	var alive: Dictionary = {}
	for enemy in enemies:
		alive[enemy] = true
	for key: Tank in _arrows.keys():
		if not alive.has(key) or not is_instance_valid(key):
			var arrow: TextureRect = _arrows[key]
			arrow.queue_free()
			var removed := _arrows.erase(key)
			if not removed:
				pass


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


func _set_arrow_visible(enemy: Tank, visible: bool) -> void:
	if not _arrows.has(enemy):
		return
	_arrows[enemy].visible = visible


func _hide_all_arrows() -> void:
	for arrow: TextureRect in _arrows.values():
		arrow.visible = false
