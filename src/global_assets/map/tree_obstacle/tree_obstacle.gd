class_name TreeObstacle extends Area2D

@export var tree_configs: Array[TreeConfig] = []

var slow_ratio: float

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	Utils.connect_checked(body_entered, _on_body_entered)
	_random_tree()


func _on_body_entered(body: Node2D) -> void:
	if body is Tank:
		var tank: Tank = body

		# Resist linear motion
		var forward_dir: Vector2 = tank.transform.x.normalized()
		var forward_speed: float = tank.linear_velocity.dot(forward_dir)
		var linear_impulse_mag: float = tank.mass * forward_speed * (1.0 - slow_ratio)
		tank.apply_impulse(-forward_dir * linear_impulse_mag)

		queue_free()


func _random_tree() -> void:
	if tree_configs.is_empty():
		return

	var total_chance: float = 0.0
	for config in tree_configs:
		total_chance += config.spawn_chance

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(global_position)
	var pick: float = rng.randf() * total_chance
	var accum: float = 0.0
	for config in tree_configs:
		accum += config.spawn_chance
		if pick < accum:
			sprite.texture = config.texture
			slow_ratio = config.slow_ratio
			return
