class_name HeaderPanel
extends PanelContainer

signal garage_menu_pressed

var player_data: PlayerData = PlayerData.get_instance()

@onready var dollars_label: Label = %DollarsLabel
@onready var bonds_label: Label = %BondsLabel
@onready var garage_menu_button: Button = %GarageMenuButton
@onready var play_button: Button = %PlayButton
@onready var warning_label: Label = %WarningLabel
@onready var warning_label_container: Control = %WarningLabelContainer


func _ready() -> void:
	Utils.connect_checked(garage_menu_button.pressed, func() -> void: garage_menu_pressed.emit())
	Utils.connect_checked(play_button.pressed, _on_play_pressed)


func display_player_data() -> void:
	var dollars: int = player_data.dollars
	var bonds: int = player_data.bonds
	dollars_label.text = Utils.format_dollars(dollars)
	bonds_label.text = Utils.format_bonds(bonds)


func _on_play_pressed() -> void:
	if not player_data.is_selected_tank_valid():
		_display_warning("SELECT A TANK")
		return
	var tank_config: PlayerTankConfig = player_data.get_current_tank_config()
	if tank_config.get_total_shell_count() == 0:
		_display_warning("NOT ENOUGH AMMO")
		return
	SignalBus.play_pressed.emit()


func _display_warning(text: String) -> void:
	var scene_tree := get_tree()
	warning_label_container.visible = true
	warning_label.text = text
	await scene_tree.create_timer(3.0).timeout
	warning_label_container.visible = false
