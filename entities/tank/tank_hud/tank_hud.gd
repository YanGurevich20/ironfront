class_name TankHUD extends Control

const IMPACT_RESULT_TYPE := ShellSpec.ImpactResultType

var impact_timer: SceneTreeTimer
var settings_data: SettingsData

@onready var player_name_label: Label = %PlayerName
@onready var tank_name_label: Label = %TankName
@onready var health_bar: TextureProgressBar = %HealthBar
@onready var health_value_label: Label = %HealthValue
@onready var impact_result_type_label: Label = %ImpactResultType
@onready var damage_ticker_label: Label = %DamageTicker


func _ready() -> void:
	_hide_impact_result()
	settings_data = SettingsData.get_instance()
	Utils.connect_checked(GameplayBus.settings_changed, _apply_settings)
	_apply_settings()


func _apply_settings() -> void:
	modulate.a = settings_data.tank_hud_opacity


func initialize(tank: Tank) -> void:
	var player_data := PlayerData.get_instance()
	var resolved_player_name: String = tank.display_player_name.strip_edges()
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
	var result_type := impact_result.result_type
	if impact_timer != null and impact_timer.timeout.is_connected(_hide_impact_result):
		impact_timer.timeout.disconnect(_hide_impact_result)

	var result_name: String = IMPACT_RESULT_TYPE.find_key(result_type)
	impact_result_type_label.text = result_name.capitalize() + "!"
	impact_result_type_label.show()

	damage_ticker_label.text = "-" + str(impact_result.damage)
	if impact_result.damage > 0:
		damage_ticker_label.show()

	impact_timer = get_tree().create_timer(1.0)
	Utils.connect_checked(impact_timer.timeout, _hide_impact_result)


func _hide_impact_result() -> void:
	impact_result_type_label.hide()
	damage_ticker_label.hide()
	impact_timer = null
