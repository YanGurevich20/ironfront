class_name LevelSelectOverlay
extends BaseOverlay

@export var level_star_unlock_threshold: int = 2

@onready var levels_container: VBoxContainer = %LevelsContainer
@onready var level_button_scene: PackedScene = preload(
	"res://src/ui/login_menu/components/level_button/level_button.tscn"
)


func _ready() -> void:
	super._ready()
	Utils.connect_checked(root_section.back_pressed, _on_root_back_pressed)


func display_levels() -> void:
	for child in levels_container.get_children():
		levels_container.remove_child(child)
		child.queue_free()
	var lock_next_level: bool = false
	var player_data := PlayerData.get_instance()
	for level: int in LevelManager.LEVEL_SCENES.keys():
		var level_button: LevelButton = level_button_scene.instantiate()
		var level_stars: int = player_data.get_stars_for_level(level)
		level_button.disabled = lock_next_level
		if level_stars < level_star_unlock_threshold:
			lock_next_level = true
		level_button.level = level
		level_button.stars = level_stars
		Utils.connect_checked(level_button.pressed, func() -> void: UiBus.level_pressed.emit(level))
		levels_container.add_child(level_button)


func _on_root_back_pressed(is_root_section: bool) -> void:
	if is_root_section:
		exit_overlay_pressed.emit()
