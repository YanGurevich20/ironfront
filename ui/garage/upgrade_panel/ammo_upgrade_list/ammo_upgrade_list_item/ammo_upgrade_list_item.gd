class_name AmmoUpgradeListItem
extends HBoxContainer

signal count_updated

enum State { LOCKED = 0, UNLOCKABLE = 1, UNLOCKED = 2 }

const MAX_TICK_COUNT: int = 20

var shell_spec: ShellSpec
var current_count: int
var current_allowed_count: int
var state: State:
	set(value):
		_state = value
		var is_unlocked := _state == State.UNLOCKED
		match _state:
			State.LOCKED:
				_set_lock_overlay_visibility(true)
				_set_unlockable_overlay_visibility(false)
				_set_price_label_properties(true, "")
				_set_shell_button_properties(true, Control.MOUSE_FILTER_STOP)
			State.UNLOCKABLE:
				_set_lock_overlay_visibility(false)
				_set_unlockable_overlay_visibility(true)
				_set_price_label_properties(true, "GoldLabel")
				_set_shell_button_properties(false, Control.MOUSE_FILTER_STOP)
			State.UNLOCKED:
				_set_lock_overlay_visibility(false)
				_set_unlockable_overlay_visibility(false)
				_set_price_label_properties(false, "")
				_set_shell_button_properties(false, Control.MOUSE_FILTER_IGNORE)
		_set_ammo_controls_enabled(is_unlocked)
	get:
		return _state
var _state: State = State.LOCKED

@onready var shell_button: Button = %ShellButton
@onready var shell_icon: TextureRect = %ShellIcon
@onready var count_slider: HSlider = %CountSlider
@onready var count_input: LineEdit = %CountInput
@onready var count_increment_button: Button = %CountIncrementButton
@onready var count_decrement_button: Button = %CountDecrementButton
@onready var info_button: Button = %InfoButton
@onready var ammo_count_container: HBoxContainer = %AmmoCountContainer
@onready var shell_name_label: Label = %ShellNameLabel
@onready var shell_stats_label: Label = %ShellStatsLabel
@onready var lock_overlay: TextureRect = %LockOverlay
@onready var lock_color_overlay: ColorRect = %LockColorOverlay
@onready var unlockable_overlay: TextureRect = %UnlockableOverlay
@onready var price_label: Label = %PriceLabel


func display_shell(
	player_tank_config: PlayerTankConfig, shell_spec_data: ShellSpec, player_dollars: int
) -> void:
	shell_spec = shell_spec_data
	var tank_spec := TankManager.tank_specs[player_tank_config.tank_id]
	var is_locked: bool = not player_tank_config.shell_amounts.has(shell_spec)
	var max_allowed_count := tank_spec.shell_capacity
	shell_icon.texture = shell_spec.base_shell_type.round_texture
	shell_name_label.text = shell_spec.shell_name
	shell_stats_label.text = (
		"D: %dHP | P: %dmm" % [shell_spec.damage, roundi(shell_spec.penetration)]
	)
	count_slider.max_value = max_allowed_count
	count_slider.tick_count = clamp(max_allowed_count + 1, 2, MAX_TICK_COUNT)
	ammo_count_container.show()
	price_label.text = Utils.format_dollars(shell_spec.unlock_cost)
	if is_locked:
		current_allowed_count = 0
		update_count(0)
		if player_dollars >= shell_spec.unlock_cost:
			state = State.UNLOCKABLE
		else:
			state = State.LOCKED
	else:
		var loaded_count := player_tank_config.get_shell_amount(shell_spec)
		var current_total_count := player_tank_config.get_total_shell_count()
		var unallocated_count: int = max_allowed_count - current_total_count
		current_allowed_count = loaded_count + unallocated_count
		update_count(loaded_count)
		state = State.UNLOCKED


func _ready() -> void:
	Utils.connect_checked(shell_button.pressed, func() -> void: _on_shell_button_pressed())
	Utils.connect_checked(
		count_decrement_button.pressed, func() -> void: update_count(current_count - 1)
	)
	Utils.connect_checked(
		count_increment_button.pressed, func() -> void: update_count(current_count + 1)
	)
	Utils.connect_checked(
		count_slider.value_changed, func(value: float) -> void: update_count(int(value))
	)
	Utils.connect_checked(
		count_input.text_submitted, func(text: String) -> void: update_count(int(text))
	)
	Utils.connect_checked(
		info_button.pressed, func() -> void: SignalBus.shell_info_requested.emit(shell_spec)
	)


func _set_shell_button_properties(disabled: bool, mouse_filter_value: Control.MouseFilter) -> void:
	shell_button.disabled = disabled
	shell_button.mouse_filter = mouse_filter_value


func _set_price_label_properties(show_price_label: bool, theme_type_variation_name: String) -> void:
	price_label.visible = show_price_label
	price_label.theme_type_variation = theme_type_variation_name


func _set_lock_overlay_visibility(show_lock_overlay: bool) -> void:
	lock_overlay.visible = show_lock_overlay
	lock_color_overlay.visible = show_lock_overlay


func _set_unlockable_overlay_visibility(show_unlockable_overlay: bool) -> void:
	unlockable_overlay.visible = show_unlockable_overlay


func _on_shell_button_pressed() -> void:
	if state == State.UNLOCKABLE:
		SignalBus.shell_unlock_requested.emit(shell_spec)


func _set_ammo_controls_enabled(enabled: bool) -> void:
	count_slider.editable = enabled
	count_input.editable = enabled
	count_increment_button.disabled = not enabled
	count_decrement_button.disabled = not enabled


func update_count(new_count: int) -> void:
	current_count = clamp(new_count, 0, current_allowed_count)
	count_slider.value = current_count
	count_input.text = str(current_count)
	update_buttons()
	save_count()
	count_updated.emit()


func update_buttons() -> void:
	if not count_slider.editable:
		count_decrement_button.disabled = true
		count_increment_button.disabled = true
		return
	count_decrement_button.disabled = current_count == 0
	count_increment_button.disabled = current_count == current_allowed_count


func save_count() -> void:
	var player_data := PlayerData.get_instance()
	var current_tank_config: PlayerTankConfig = player_data.get_current_tank_config()

	#? Only save if the shell is unlocked (exists in the shell_amounts dictionary)
	if current_tank_config.shell_amounts.has(shell_spec):
		current_tank_config.set_shell_amount(shell_spec, current_count)
		player_data.save()
