class_name DestroyedTank extends RigidBody2D

var turret_rotation: float
@onready var turret :Sprite2D= $Turret

func _ready() -> void:
	turret.rotation = turret_rotation