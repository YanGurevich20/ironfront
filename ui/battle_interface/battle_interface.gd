class_name BattleInterface extends Control

@onready var tank_control: TankControl = $TankControl


func reset_input() -> void:
	tank_control.reset_input()


func display_controls() -> void:
	tank_control.display_controls()
