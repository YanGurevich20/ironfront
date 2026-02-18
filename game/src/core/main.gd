class_name Main
extends Node

var client_scene: PackedScene = preload("res://src/core/client/client_app.tscn")
var server_scene: PackedScene = preload("res://src/core/server/server_app.tscn")


func _ready() -> void:
	var is_server: bool = Env.get_flag("server")
	if OS.has_feature("dedicated_server") or is_server:
		var server_runtime: ServerApp = server_scene.instantiate()
		add_child(server_runtime)
		print("[main] launched server runtime")
	else:
		var client_runtime: ClientApp = client_scene.instantiate()
		add_child(client_runtime)
		print("[main] launched client runtime")
