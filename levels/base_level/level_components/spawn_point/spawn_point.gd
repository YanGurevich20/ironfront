class_name SpawnPoint extends Marker2D

func _ready() -> void:
	remove_child($DebugArrowSprite)

enum Type {PLAYER, ENEMY}
@export var type: Type = Type.ENEMY
