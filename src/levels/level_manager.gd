class_name LevelManager extends Node

# === Constants ===
const LEVEL_SCENES: Dictionary[int, PackedScene] = {
	0: preload("res://src/levels/level_0.tscn"),
	1: preload("res://src/levels/level_1.tscn"),
	2: preload("res://src/levels/level_2.tscn"),
	3: preload("res://src/levels/level_3.tscn"),
}
