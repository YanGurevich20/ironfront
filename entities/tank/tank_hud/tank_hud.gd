class_name TankHUD extends Control

@onready var player_name_label :Label = %PlayerName
@onready var tank_name_label :Label = %TankName
@onready var health_bar :TextureProgressBar = %HealthBar
@onready var health_value_label :Label = %HealthValue
@onready var impact_result_type_label :Label = %ImpactResultType

var tank_reference: Tank
const ImpactResultType := ShellSpec.ImpactResultType

func _ready() -> void:
	pass

func initialize(tank: Tank) -> void:
	tank_reference = tank
	var player_data := PlayerData.get_instance()
	player_name_label.text = player_data.player_name if tank.is_player else "AI"
	health_bar.tint_progress = Colors.FRIENDLY_GREEN if tank.is_player else Colors.ENEMY_RED

	tank_name_label.text = tank.tank_spec.display_name
	health_bar.max_value = tank.tank_spec.health
	update_health_bar(tank.tank_spec.health)

func update_health_bar(health: int) -> void:
	health_bar.value = health
	health_value_label.text = str(health)

func update_hud_position() -> void:
	assert(tank_reference != null, "Tank reference is not set")
	var biggest_dimension :float= max(tank_reference.tank_spec.hull_size.x, tank_reference.tank_spec.hull_size.y)
	global_position = tank_reference.global_position + Vector2(0, -biggest_dimension) - size / 2
	rotation = -tank_reference.global_rotation

func update_impact_result(result: ImpactResultType) -> void:
	var result_name: String = ImpactResultType.find_key(result)
	impact_result_type_label.text = result_name.capitalize() + "!"
	impact_result_type_label.show()
	await get_tree().create_timer(1.0).timeout
	impact_result_type_label.hide()
