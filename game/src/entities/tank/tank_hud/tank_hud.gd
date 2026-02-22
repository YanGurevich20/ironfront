class_name TankHUD extends Control

var damage_ticker_timer: SceneTreeTimer
var settings_data: SettingsData

@onready var player_name_label: Label = %PlayerName
@onready var tank_name_label: Label = %TankName
@onready var health_bar: TextureProgressBar = %HealthBar
@onready var health_value_label: Label = %HealthValue
@onready var damage_ticker_label: Label = %DamageTicker


func _ready() -> void:
	_hide_damage_ticker()
	settings_data = SettingsData.get_instance()
	Utils.connect_checked(GameplayBus.settings_changed, _apply_settings)
	_apply_settings()


func _apply_settings() -> void:
	modulate.a = settings_data.tank_hud_opacity


func initialize(tank: Tank) -> void:
	var player_data := PlayerData.get_instance()
	var resolved_player_name: String = tank.display_player_name
	if resolved_player_name.is_empty():
		resolved_player_name = player_data.player_name if tank.is_player else "AI"
	player_name_label.text = resolved_player_name
	health_bar.tint_progress = Colors.FRIENDLY_GREEN if tank.is_player else Colors.ENEMY_RED
	damage_ticker_label.modulate = Colors.ENEMY_RED if tank.is_player else Colors.GOLD

	tank_name_label.text = tank.tank_spec.display_name
	health_bar.max_value = tank.tank_spec.health
	update_health_bar(tank.tank_spec.health)


func update_health_bar(health: int) -> void:
	health_bar.value = health
	health_value_label.text = str(health)


func handle_impact_result(impact_result: ShellSpec.ImpactResult) -> void:
	if (
		damage_ticker_timer != null
		and damage_ticker_timer.timeout.is_connected(_hide_damage_ticker)
	):
		damage_ticker_timer.timeout.disconnect(_hide_damage_ticker)

	damage_ticker_label.text = "-" + str(impact_result.damage)
	if impact_result.damage > 0:
		damage_ticker_label.show()
	else:
		damage_ticker_label.hide()

	damage_ticker_timer = get_tree().create_timer(1.0)
	Utils.connect_checked(damage_ticker_timer.timeout, _hide_damage_ticker)


func _hide_damage_ticker() -> void:
	damage_ticker_label.hide()
	damage_ticker_timer = null
