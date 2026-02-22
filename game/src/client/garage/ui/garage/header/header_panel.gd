class_name HeaderPanel
extends PanelContainer

signal play_requested
signal garage_menu_pressed

var feedback_display_token: int = 0

@onready var dollars_label: Label = %DollarsLabel
@onready var bonds_label: Label = %BondsLabel
@onready var garage_menu_button: Button = %GarageMenuButton
@onready var play_button: Button = %PlayButton
@onready var warning_label: Label = %WarningLabel
@onready var warning_label_container: Control = %WarningLabelContainer


func _ready() -> void:
	Utils.connect_checked(garage_menu_button.pressed, _on_garage_menu_pressed)
	Utils.connect_checked(play_button.pressed, _on_play_pressed)
	Utils.connect_checked(
		Account.economy.dollars_updated, func(_new_dollars: int) -> void: _refresh_economy_labels()
	)
	Utils.connect_checked(
		Account.economy.bonds_updated, func(_new_bonds: int) -> void: _refresh_economy_labels()
	)
	_refresh_economy_labels()


func _refresh_economy_labels() -> void:
	dollars_label.text = Utils.format_dollars(Account.economy.dollars)
	bonds_label.text = Utils.format_bonds(Account.economy.bonds)


func _on_play_pressed() -> void:
	var tank_config: TankConfig = Account.loadout.get_selected_tank_config()
	var total_shell_count: int = 0
	for shell_count_variant: Variant in tank_config.shell_loadout_by_spec.values():
		total_shell_count += int(shell_count_variant)
	if total_shell_count == 0:
		_display_warning("NOT ENOUGH AMMO")
		return
	play_requested.emit()


func _display_warning(text: String) -> void:
	_display_feedback(text)


func display_online_feedback(message: String, is_error: bool) -> void:
	var feedback_message: String = message
	if not is_error:
		feedback_message = "OK: %s" % feedback_message
	_display_feedback(feedback_message)


func _on_garage_menu_pressed() -> void:
	garage_menu_pressed.emit()


func _display_feedback(text: String) -> void:
	var scene_tree := get_tree()
	feedback_display_token += 1
	var token: int = feedback_display_token
	warning_label_container.visible = true
	warning_label.text = text
	await scene_tree.create_timer(3.0).timeout
	if token != feedback_display_token:
		return
	warning_label_container.visible = false
