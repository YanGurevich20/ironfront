class_name Main
extends Node

var server_scene: PackedScene = preload("res://src/server/server_app.tscn")
var client_scene: PackedScene = preload("res://src/client/client_app.tscn")


func _ready() -> void:
	if OS.has_feature("dedicated_server") or Env.get_flag("server"):
		add_child(server_scene.instantiate())
		print("[main] launched server runtime")
	else:
		add_child(client_scene.instantiate())
		print("[main] launched client runtime")
