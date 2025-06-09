class_name Turret
extends Sprite2D

@onready var tank :Tank= get_parent()
@onready var cannon :Sprite2D= $Cannon
@onready var muzzle :Marker2D= $Cannon/MuzzleMarker
@onready var flash :AnimatedSprite2D= %MuzzleFlash
@onready var reload_timer: Timer = %ReloadTimer
@onready var line_of_sight_raycast: RayCast2D = %LineOfSightRaycast
@onready var cannon_sound: AudioStreamPlayer2D = %CannonSound

var shell_scene: PackedScene = preload("res://entities/shell/shell.tscn")
var remaining_shell_count: int = 1
var current_shell_id: ShellManager.ShellId

func _ready() -> void:
	flash.animation_finished.connect(func()->void:flash.visible=false)
	reload_timer.timeout.connect(func()->void:SignalBus.reload_progress_left_updated.emit(1.0, tank))
	current_shell_id = tank.tank_spec.allowed_shells[0]
	line_of_sight_raycast.add_exception(tank)

#region Rotation Handling

func process(delta: float, rotation_input: float) -> void:
	rotation_degrees += rotation_input * tank.tank_spec.max_turret_traverse_speed * delta
	if not reload_timer.is_stopped():
		SignalBus.reload_progress_left_updated.emit(get_reload_progress(), tank)
#endregion

#region Line of Sight
func has_line_of_sight(target: Node2D) -> bool:
	line_of_sight_raycast.target_position = muzzle.to_local(target.global_position)
	line_of_sight_raycast.force_raycast_update()
	return not line_of_sight_raycast.is_colliding() or line_of_sight_raycast.get_collider() == target
#endregion

#region Shell Firing
func fire_shell() -> void:
	if remaining_shell_count <= 0:
		reload_timer.stop()
		return
	if not reload_timer.is_stopped():
		return
	var shell: Shell = shell_scene.instantiate()
	shell.initialize(current_shell_id, muzzle, tank)
	SignalBus.shell_fired.emit(shell, tank)
	SignalBus.reload_progress_left_updated.emit(0.0, tank)

	reload_timer.start(tank.tank_spec.reload_time)
	cannon_sound.play()

	# Muzzle Flash
	flash.visible = true
	flash.play("flash")

	# Recoil Animation
	var tween := get_tree().create_tween()
	var original_cannon_x: float = tank.tank_spec.cannon_offset.x
	tween.tween_property(cannon, "position:x", original_cannon_x - 10.0, 0.02).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(cannon, "position:x", original_cannon_x, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# Knockback Impulse
	var recoil_vector :Vector2 = -muzzle.global_transform.x * 10.0 * (tank.tank_spec.cannon_caliber / 100)
	var recoil_position :Vector2= position.rotated(tank.rotation)
	tank.apply_impulse(recoil_vector, recoil_position)
#endregion

func get_reload_progress() -> float:
	return 1.0 - (reload_timer.time_left / tank.tank_spec.reload_time)

func reset_reload_timer() -> void:
	reload_timer.stop()
	reload_timer.start(tank.tank_spec.reload_time)

func set_current_shell_id(shell_id: ShellManager.ShellId) -> void:
	if shell_id != current_shell_id:
		current_shell_id = shell_id
		reset_reload_timer()
