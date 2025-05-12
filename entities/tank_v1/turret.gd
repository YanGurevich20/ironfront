extends Node2D

@export var rotation_speed := 1.0
@export var reload_speed := 2.0

@onready var cannon := $Cannon
@onready var muzzle := $Cannon/Muzzle
@onready var tank := get_parent()

var shell_scene: PackedScene = preload("res://entities/shell/shell.tscn")

func play_explosion_sound() -> void:
	$Cannon/GunfireSound.pitch_scale = randf_range(0.5, 1.5)
	$Cannon/GunfireSound.play()

func _physics_process(delta: float) -> void:
	rotation += tank.turret_rotation_input * rotation_speed * delta

func has_line_of_sight(target: Node2D) -> bool:
	var start_pos: Vector2 = muzzle.global_position
	var end_pos: Vector2 = target.global_position
	var space_state: PhysicsDirectSpaceState2D  = get_world_2d().direct_space_state

	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(start_pos, end_pos)
	query.collision_mask = 1 << 0 | 1 << 1  # Wall and player layers

	# TODO: Tried to fix the tank staying in chase when too close - didn't work.
	# Exclude the tank's own collision body
	#var parent_tank = get_parent()
	#var tank_collision = parent_tank.get_node("CollisionShape2D")  # adjust if you use CollisionPolygon2D or a different name
	#query.exclude = [tank_collision]

	var result: Dictionary = space_state.intersect_ray(query)
	if result.is_empty():
		return true  # Nothing blocked the path

	if result.get("collider") == target:
		return true

	return false  # Something is in the way

signal shell_fired(shell: Shell)
func fire_shell() -> void:
	if(!$ReloadTimer.is_stopped()):
		return

	# Shell spawn
	var shell: Shell = shell_scene.instantiate()
	shell.firing_tank = tank
	shell.global_position = muzzle.global_position
	shell.rotation = global_rotation
	shell.velocity = Vector2.RIGHT.rotated(shell.rotation) * shell.speed
	shell_fired.emit(shell)

	# Reload timer
	$ReloadTimer.start(reload_speed)

	# Play sound
	play_explosion_sound()

	# Muzzle flash
	var flash: AnimatedSprite2D = muzzle.get_node("MuzzleFlash")
	flash.visible = true
	flash.play("flash")

	# Recoil tween
	var tween: Tween = get_tree().create_tween()
	tween.tween_property(cannon, "position:x", -10.0, 0.02).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(cannon, "position:x", 0.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# Knockback
	var recoil_vector: Vector2 = -muzzle.global_transform.x * 40.0
	var recoil_position: Vector2 = position.rotated(tank.rotation)
	tank.apply_impulse(recoil_vector, recoil_position)
	#tank.apply_central_impulse(recoil_vector)

func _on_muzzle_flash_animation_finished() -> void:
	muzzle.get_node("MuzzleFlash").visible = false
