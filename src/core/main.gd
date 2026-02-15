class_name Main
extends Node

var client_scene: PackedScene = preload("res://src/core/client/client.tscn")
var server_scene: PackedScene = preload("res://src/core/server/server.tscn")


func _ready() -> void:
	var args: Dictionary = Utils.get_parsed_cmdline_user_args()
	if OS.has_feature("dedicated_server") or args.get("server", false):
		var server_runtime: Server = server_scene.instantiate()
		add_child(server_runtime)
		print("[main] launched server runtime")
	else:
		var client_runtime: Client = client_scene.instantiate()
		add_child(client_runtime)
		print("[main] launched client runtime")
