class_name BaseOverlay
extends Control

signal exit_overlay_pressed

var all_sections: Array[Control] = []

@onready var sections_container: VBoxContainer = %SectionsContainer
@onready var root_section: BaseSection = %RootSection


func _ready() -> void:
	all_sections.clear()
	for section: Node in sections_container.get_children():
		if section is Control:
			all_sections.append(section)
	show_only([root_section])


func show_only(sections_to_show: Array[Control]) -> void:
	for section: Control in all_sections:
		section.visible = section in sections_to_show
