class_name AmmoUpgradeListItem extends HBoxContainer

@onready var unlock_button: Button = %UnlockButton

@onready var shell_icon: TextureRect = %ShellIcon
@onready var count_slider: HSlider = %CountSlider
@onready var count_input: LineEdit = %CountInput
@onready var count_increment_button: Button = %CountIncrementButton
@onready var count_decrement_button: Button = %CountDecrementButton

@onready var ammo_count_container: HBoxContainer = %AmmoCountContainer
@onready var unlock_container: HBoxContainer = %UnlockContainer

const MAX_TICK_COUNT: int = 20

var shell_id: ShellManager.ShellId
var current_count: int
var current_allowed_count: int

signal count_updated(shell_id: ShellManager.ShellId, count: int)

func display_shell(player_tank_config: PlayerTankConfig, _shell_id: ShellManager.ShellId) -> void:
	shell_id = _shell_id
	var shell_spec := ShellManager.get_shell_spec(shell_id)
	var tank_spec := TankManager.get_tank_spec(player_tank_config.tank_id)
	var is_locked: bool = not player_tank_config.shells.has(shell_id)
	var max_allowed_count := tank_spec.shell_capacity
	shell_icon.texture = shell_spec.base_shell_type.round_texture
	count_slider.max_value = max_allowed_count
	count_slider.tick_count = clamp(max_allowed_count + 1, 2, MAX_TICK_COUNT)
	if not is_locked:
		ammo_count_container.show()
		unlock_container.hide()
		var loaded_count := player_tank_config.get_shell_amount(shell_id)
		current_allowed_count = loaded_count
		update_count(loaded_count)
	else:
		update_count(0)
		unlock_button.text = "UNLOCK\n" + Utils.format_dollars(shell_spec.unlock_cost)

func _ready() -> void:
	unlock_button.pressed.connect(func()->void:SignalBus.shell_unlock_requested.emit(shell_id))
	count_decrement_button.pressed.connect(func()->void:update_count(current_count - 1))
	count_increment_button.pressed.connect(func()->void:update_count(current_count + 1))
	count_slider.value_changed.connect(func(value: float)->void:update_count(int(value)))

func update_count(new_count: int) -> void:
	current_count = clamp(new_count,0,current_allowed_count)
	count_slider.value = current_count
	count_input.text = str(current_count)
	count_updated.emit(shell_id, current_count)
