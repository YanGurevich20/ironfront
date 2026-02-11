class_name TankControl
extends Control

const MIN_ZOOM_LEVEL: float = 0.5
const MAX_ZOOM_LEVEL: float = 1.5
const MIN_PINCH_DISTANCE: float = 8.0

var pinch_touch_positions: Dictionary[int, Vector2] = {}
var pinch_start_distance: float = 0.0
var pinch_start_zoom_level: float = 1.0

@onready var left_lever: Lever = $LeftLever
@onready var right_lever: Lever = $RightLever
@onready var traverse_wheel: TraverseWheel = $TraverseWheel
@onready var fire_button: FireButton = %FireButton
@onready var shell_select: ShellSelect = %ShellSelect
@onready var pause_button: Button = %PauseButton


func _ready() -> void:
	Utils.connect_checked(
		fire_button.fire_button_pressed, func() -> void: GameplayBus.fire_input.emit()
	)
	Utils.connect_checked(pause_button.pressed, func() -> void: UiBus.pause_input.emit())
	Utils.connect_checked(left_lever.lever_double_tapped, _on_lever_double_tapped)
	Utils.connect_checked(right_lever.lever_double_tapped, _on_lever_double_tapped)
	_apply_settings()
	Utils.connect_checked(GameplayBus.settings_changed, _apply_settings)


func _apply_settings() -> void:
	var settings_data: SettingsData = SettingsData.get_instance()
	modulate.a = settings_data.controls_opacity


func _set_zoom_level(value: float) -> void:
	var settings_data: SettingsData = SettingsData.get_instance()
	settings_data.zoom_level = clampf(value, MIN_ZOOM_LEVEL, MAX_ZOOM_LEVEL)


func reset_input() -> void:
	left_lever.reset_input()
	right_lever.reset_input()
	traverse_wheel.reset_input()
	fire_button.reset_input()


func display_controls() -> void:
	shell_select.initialize()


func _on_lever_double_tapped() -> void:
	left_lever.reset_input()
	right_lever.reset_input()


func _unhandled_input(event: InputEvent) -> void:
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
