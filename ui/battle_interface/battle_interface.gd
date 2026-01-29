class_name BattleInterface extends Control

@onready var tank_control: TankControl = $TankControl
@onready var enemy_indicators: EnemyIndicators = $EnemyIndicators


func finish_level() -> void:
	tank_control.reset_input()
	enemy_indicators.reset_indicators()


func start_level() -> void:
	tank_control.display_controls()
	enemy_indicators.display_indicators()
