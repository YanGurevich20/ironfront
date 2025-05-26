class_name BaseOverlay extends Control

signal exit_overlay_pressed
@onready var sections_container := $%SectionsContainer
@onready var root_section := $%RootSection

var all_sections: Array[Node]

func _ready() -> void:
	all_sections = sections_container.get_children()
	show_only([root_section])
	for section in all_sections:
		if not section is BaseSection: continue
		(section as BaseSection).back_pressed.connect(_handle_back_pressed)

func show_only(sections_to_show: Array[Node]) -> void:
	for section: Control in all_sections:
		section.visible = section in sections_to_show

func _handle_back_pressed(is_root: bool)->void:
	if is_root: exit_overlay_pressed.emit()
	else: show_only([root_section])
