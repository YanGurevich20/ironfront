class_name TankControl
extends Control

const MIN_ZOOM_LEVEL: float = 0.5
const MAX_ZOOM_LEVEL: float = 1.5
const MIN_PINCH_DISTANCE: float = 8.0

var pinch_touch_positions: Dictionary[int, Vector2] = {}
var pinch_start_distance: float = 0.0
var pinch_start_zoom_level: float = 1.0
var dual_control_active: bool = false
var dual_control_master: Lever = null
var dual_control_slave: Lever = null

@onready var left_lever: Lever = $LeftLever
@onready var right_lever: Lever = $RightLever
@onready var traverse_wheel: TraverseWheel = $TraverseWheel
@onready var fire_button: FireButton = %FireButton
@onready var shell_select: ShellSelect = %ShellSelect
@onready var pause_button: Button = %PauseButton


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Utils.connect_checked(
		fire_button.fire_button_pressed, func() -> void: GameplayBus.fire_input.emit()
	)
	Utils.connect_checked(pause_button.pressed, func() -> void: UiBus.pause_input.emit())
	Utils.connect_checked(
		left_lever.lever_double_tapped, func() -> void: _on_lever_double_tapped(left_lever)
	)
	Utils.connect_checked(
		right_lever.lever_double_tapped, func() -> void: _on_lever_double_tapped(right_lever)
	)
	Utils.connect_checked(
		left_lever.lever_moved,
		func(lever_side: Lever.LeverSide, value: float) -> void:
			_on_dual_control_master_lever_moved(left_lever, lever_side, value)
	)
	Utils.connect_checked(
		right_lever.lever_moved,
		func(lever_side: Lever.LeverSide, value: float) -> void:
			_on_dual_control_master_lever_moved(right_lever, lever_side, value)
	)
	Utils.connect_checked(
		left_lever.lever_released,
		func(lever_side: Lever.LeverSide, is_locked: bool) -> void:
			_on_dual_control_master_lever_released(left_lever, lever_side, is_locked)
	)
	Utils.connect_checked(
		right_lever.lever_released,
		func(lever_side: Lever.LeverSide, is_locked: bool) -> void:
			_on_dual_control_master_lever_released(right_lever, lever_side, is_locked)
	)
	Utils.connect_checked(
		left_lever.lever_lock_changed,
		func(lever_side: Lever.LeverSide, is_locked: bool) -> void:
			_on_dual_control_master_lock_changed(left_lever, lever_side, is_locked)
	)
	Utils.connect_checked(
		right_lever.lever_lock_changed,
		func(lever_side: Lever.LeverSide, is_locked: bool) -> void:
			_on_dual_control_master_lock_changed(right_lever, lever_side, is_locked)
	)
	_apply_settings()
	Utils.connect_checked(GameplayBus.settings_changed, _apply_settings)


func _apply_settings() -> void:
	var settings_data: SettingsData = SettingsData.get_instance()
	modulate.a = settings_data.controls_opacity


func _set_zoom_level(value: float) -> void:
	var settings_data: SettingsData = SettingsData.get_instance()
	settings_data.zoom_level = clampf(value, MIN_ZOOM_LEVEL, MAX_ZOOM_LEVEL)


func reset_input() -> void:
	_clear_dual_control_state()
	left_lever.reset_input()
	right_lever.reset_input()
	traverse_wheel.reset_input()
	fire_button.reset_input()


func _on_lever_double_tapped(source_lever: Lever) -> void:
	dual_control_active = true
	dual_control_master = source_lever
	dual_control_slave = right_lever if source_lever == left_lever else left_lever
	_sync_dual_control_slave(dual_control_master.lever_value)


func _on_dual_control_master_lever_moved(
	source_lever: Lever, lever_side: Lever.LeverSide, value: float
) -> void:
	if not dual_control_active:
		return
	if source_lever != dual_control_master:
		return
	if dual_control_slave == null:
		return
	if lever_side != source_lever.lever_side:
		return
	_sync_dual_control_slave(value)


func _on_dual_control_master_lever_released(
	source_lever: Lever, lever_side: Lever.LeverSide, is_locked: bool
) -> void:
	if not dual_control_active:
		return
	if source_lever != dual_control_master:
		return
	if lever_side != source_lever.lever_side:
		return
	if is_locked:
		_sync_dual_control_slave(source_lever.lever_value)
	else:
		left_lever.reset_input()
		right_lever.reset_input()
	_clear_dual_control_state()


func _on_dual_control_master_lock_changed(
	source_lever: Lever, lever_side: Lever.LeverSide, is_locked: bool
) -> void:
	if not dual_control_active:
		return
	if source_lever != dual_control_master:
		return
	if lever_side != source_lever.lever_side:
		return
	if is_locked != source_lever.should_lock_last_value:
		return
	_sync_dual_control_slave(source_lever.lever_value)


func _sync_dual_control_slave(master_value: float) -> void:
	if dual_control_master == null:
		return
	if dual_control_slave == null:
		return
	var clamped_value: float = clampf(master_value, -1.0, 1.0)
	var step: int = int(
		round(float(Lever.CENTER_FRAME) - clamped_value * float(Lever.CENTER_FRAME))
	)
	step = clamp(step, 0, Lever.TOTAL_FRAMES - 1)
	var step_height: float = dual_control_slave.control_field_height / float(Lever.TOTAL_FRAMES)
	dual_control_slave.should_lock_last_value = dual_control_master.should_lock_last_value
	dual_control_slave.touch_y_position = (float(step) + 0.5) * step_height
	dual_control_slave.update_lever()


func _clear_dual_control_state() -> void:
	dual_control_active = false
	dual_control_master = null
	dual_control_slave = null


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		_handle_pinch_touch(event)
	elif event is InputEventScreenDrag:
		_handle_pinch_drag(event)


func _handle_pinch_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		pinch_touch_positions[event.index] = event.position
		_capture_pinch_start()
		return
	var removed := pinch_touch_positions.erase(event.index)
	if not removed:
		pass
	_capture_pinch_start()


func _handle_pinch_drag(event: InputEventScreenDrag) -> void:
	if not pinch_touch_positions.has(event.index):
		return
	pinch_touch_positions[event.index] = event.position
	if pinch_touch_positions.size() != 2:
		return
	var current_distance: float = _get_pinch_distance()
	if pinch_start_distance < MIN_PINCH_DISTANCE or current_distance < MIN_PINCH_DISTANCE:
		return
	var target_zoom_level: float = (
		pinch_start_zoom_level * (current_distance / pinch_start_distance)
	)
	_set_zoom_level(target_zoom_level)


func _capture_pinch_start() -> void:
	if pinch_touch_positions.size() != 2:
		pinch_start_distance = 0.0
		return
	pinch_start_distance = _get_pinch_distance()
	pinch_start_zoom_level = SettingsData.get_instance().zoom_level


func _get_pinch_distance() -> float:
	var touch_positions: Array[Vector2] = []
	for touch_position: Vector2 in pinch_touch_positions.values():
		touch_positions.append(touch_position)
	if touch_positions.size() != 2:
		return 0.0
	return touch_positions[0].distance_to(touch_positions[1])
