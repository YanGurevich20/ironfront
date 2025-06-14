class_name AmmoUpgradeListItem extends HBoxContainer

@onready var unlock_button: Button = %UnlockButton

@onready var shell_icon: TextureRect = %ShellIcon
@onready var count_slider: HSlider = %CountSlider
@onready var count_input: LineEdit = %CountInput
@onready var count_increment_button: Button = %CountIncrementButton
@onready var count_decrement_button: Button = %CountDecrementButton
@onready var info_button: Button = %InfoButton
@onready var shell_name_label: Label = %ShellName

@onready var ammo_count_container: HBoxContainer = %AmmoCountContainer
@onready var unlock_container: HBoxContainer = %UnlockContainer

const MAX_TICK_COUNT: int = 20

var shell_spec: ShellSpec
var current_count: int
var current_allowed_count: int

signal count_updated()

func display_shell(player_tank_config: PlayerTankConfig, _shell_spec: ShellSpec) -> void:
	shell_spec = _shell_spec
	var tank_spec := TankManager.TANK_SPECS[player_tank_config.tank_id]
	var is_locked: bool = not player_tank_config.shell_amounts.has(shell_spec)
	var max_allowed_count := tank_spec.shell_capacity
	shell_name_label.text = shell_spec.shell_name
	shell_icon.texture = shell_spec.base_shell_type.round_texture
	count_slider.max_value = max_allowed_count
	count_slider.tick_count = clamp(max_allowed_count + 1, 2, MAX_TICK_COUNT)
	if not is_locked:
		ammo_count_container.show()
		unlock_container.hide()
		current_allowed_count = max_allowed_count
		var loaded_count := player_tank_config.get_shell_amount(shell_spec)
		update_count(loaded_count)
	else:
		ammo_count_container.hide()
		unlock_container.show()
		update_count(0)
		unlock_button.text = "UNLOCK\n" + Utils.format_dollars(shell_spec.unlock_cost)

func _ready() -> void:
	unlock_button.pressed.connect(func()->void:SignalBus.shell_unlock_requested.emit(shell_spec))
	count_decrement_button.pressed.connect(func()->void:update_count(current_count - 1))
	count_increment_button.pressed.connect(func()->void:update_count(current_count + 1))
	count_slider.value_changed.connect(func(value: float)->void:update_count(int(value)))
	count_input.text_submitted.connect(func(text: String)->void:update_count(int(text)))
	info_button.pressed.connect(func()->void:SignalBus.shell_info_requested.emit(shell_spec))

func update_count(new_count: int) -> void:
	current_count = clamp(new_count,0,current_allowed_count)
	count_slider.value = current_count
	count_input.text = str(current_count)
	update_buttons()
	save_count()
	count_updated.emit()

func update_buttons() -> void:
	count_decrement_button.disabled = current_count == 0
	count_increment_button.disabled = current_count == current_allowed_count

func save_count() -> void:
	var player_data := PlayerData.get_instance()
	var current_tank_config: PlayerTankConfig = player_data.get_current_tank_config()

	#? Only save if the shell is unlocked (exists in the shell_amounts dictionary)
	if current_tank_config.shell_amounts.has(shell_spec):
		current_tank_config.set_shell_amount(shell_spec, current_count)
		player_data.save()
