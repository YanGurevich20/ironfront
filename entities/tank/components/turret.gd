class_name Turret
extends Sprite2D

@onready var tank :Tank= get_parent()
@onready var cannon := $Cannon
@onready var muzzle := $Cannon/MuzzleMarker
@onready var flash := $Cannon/MuzzleMarker/MuzzleFlash
@onready var reload_timer: Timer = $ReloadTimer
@onready var line_of_sight_raycast: RayCast2D = $Cannon/MuzzleMarker/LineOfSightRaycast

# TODO: Handle multiple shell types (AP, HE, etc.) via shell_scene switching
var shell_scene: PackedScene = preload("res://entities/shell/shell.tscn")

func _ready() -> void:
	flash.animation_finished.connect(func()->void:flash.visible=false)
	reload_timer.timeout.connect(func()->void:SignalBus.reload_progress_left_updated.emit(1.0, tank))

#region Rotation Handling
func _process(delta: float) -> void:
	rotation_degrees += tank.turret_rotation_input * tank.tank_spec.max_turret_traverse_speed * delta
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
func fire_shell(shell_id: ShellManager.ShellId) -> void:
	if not reload_timer.is_stopped():
		return
	var shell: Shell = shell_scene.instantiate()
	shell.initialize(shell_id, muzzle, tank)
	SignalBus.shell_fired.emit(shell, tank)
	SignalBus.reload_progress_left_updated.emit(0.0, tank)

	reload_timer.start(tank.tank_spec.reload_time)
	$CannonSound.play()

	# Muzzle Flash
	flash.visible = true
	flash.play("flash")

	# Recoil Animation
	var tween := get_tree().create_tween()
	var original_x :float= cannon.position.x
	tween.tween_property(cannon, "position:x", original_x - 10.0, 0.02).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(cannon, "position:x", original_x, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# Knockback Impulse
	var recoil_vector :Vector2 = -muzzle.global_transform.x * 40.0 * (tank.tank_spec.cannon_caliber / 100)
	var recoil_position :Vector2= position.rotated(tank.rotation)
	tank.apply_impulse(recoil_vector, recoil_position)
#endregion

func get_reload_progress() -> float:
	return 1.0 - (reload_timer.time_left / tank.tank_spec.reload_time)

func reset_reload_timer() -> void:
	reload_timer.stop()
	reload_timer.start(tank.tank_spec.reload_time)