class_name SpawnPoint extends Marker2D

func _ready() -> void:
	remove_child($DebugArrowSprite)

enum Type {PLAYER=0, ENEMY=1, DUMMY=2}
@export var type: Type = Type.ENEMY
