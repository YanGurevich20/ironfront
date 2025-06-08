class_name TankHUD extends Control

@onready var player_name_label :Label = %PlayerName
@onready var tank_name_label :Label = %TankName
@onready var health_bar :TextureProgressBar = %HealthBar
@onready var health_value_label :Label = %HealthValue
@onready var impact_result_type_label :Label = %ImpactResultType
@onready var damage_ticker_label :Label = %DamageTicker

var tank_reference: Tank
var impact_timer: SceneTreeTimer
const ImpactResultType := ShellSpec.ImpactResultType

func _ready() -> void:
	_hide_impact_result()

func initialize(tank: Tank) -> void:
	tank_reference = tank
	var player_data := PlayerData.get_instance()
	player_name_label.text = player_data.player_name if tank.is_player else "AI"
	health_bar.tint_progress = Colors.FRIENDLY_GREEN if tank.is_player else Colors.ENEMY_RED
	damage_ticker_label.modulate = Colors.ENEMY_RED if tank.is_player else Colors.GOLD

	tank_name_label.text = tank.tank_spec.display_name
	health_bar.max_value = tank.tank_spec.health
	update_health_bar(tank.tank_spec.health)

func update_health_bar(health: int) -> void:
	health_bar.value = health
	health_value_label.text = str(health)

func update_hud_position() -> void:
	assert(tank_reference != null, "Tank reference is not set")
	var biggest_dimension :float= max(tank_reference.tank_spec.hull_size.x, tank_reference.tank_spec.hull_size.y)
	global_position = tank_reference.global_position - Vector2(size.x / 2, biggest_dimension)
	rotation = -tank_reference.global_rotation

func handle_impact_result(impact_result: ShellSpec.ImpactResult) -> void:
	var result_type := impact_result.result_type
	if impact_timer != null and impact_timer.timeout.is_connected(_hide_impact_result):
		impact_timer.timeout.disconnect(_hide_impact_result)

	var result_name: String = ImpactResultType.find_key(result_type)
	impact_result_type_label.text = result_name.capitalize() + "!"
	impact_result_type_label.show()

	damage_ticker_label.text = "-" + str(impact_result.damage)
	if impact_result.damage > 0: damage_ticker_label.show()

	impact_timer = get_tree().create_timer(1.0)
	impact_timer.timeout.connect(_hide_impact_result)

func _hide_impact_result() -> void:
	impact_result_type_label.hide()
	damage_ticker_label.hide()
	impact_timer = null
