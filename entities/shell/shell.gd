class_name Shell extends Area2D

@export var speed :float= 800.0
@export var damage :int = 300
var velocity := Vector2.ZERO
var firing_tank: Node2D

func _physics_process(delta: float)->void:
	position += velocity * delta

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("projectile_blocker"):
		queue_free()
	if !body.is_in_group("damageable"):
		return
	if !body.has_method("take_damage"):
		return
	if body == firing_tank:
		return
	body.take_damage(damage)
	queue_free()
