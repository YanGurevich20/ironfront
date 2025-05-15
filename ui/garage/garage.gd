class_name Garage extends Control

@onready var tank_list: TankListPanel = %TankListPanel

func _ready() -> void:
	tank_list.display_tanks(TankManager.TANK_SPECS)

