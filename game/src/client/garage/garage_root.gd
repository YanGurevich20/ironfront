class_name GarageRoot
extends Control

signal play_requested
signal logout_requested
signal settings_requested

@onready var garage: Garage = $Garage
@onready var garage_menu_overlay: GarageMenuOverlay = %GarageMenuOverlay


func _ready() -> void:
	Utils.connect_checked(garage.play_requested, func() -> void: play_requested.emit())
	Utils.connect_checked(garage.header_panel.garage_menu_pressed, _on_garage_menu_pressed)
	Utils.connect_checked(garage_menu_overlay.exit_overlay_pressed, _on_overlay_exit)
	Utils.connect_checked(
		garage_menu_overlay.settings_pressed, func() -> void: settings_requested.emit()
	)
	Utils.connect_checked(
		garage_menu_overlay.logout_pressed, func() -> void: logout_requested.emit()
	)


func _on_garage_menu_pressed() -> void:
	garage_menu_overlay.visible = true


func _on_overlay_exit() -> void:
	garage_menu_overlay.visible = false
	UiBus.resume_requested.emit()
